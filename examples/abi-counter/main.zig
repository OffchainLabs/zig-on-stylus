// ABI-Compatible Counter Contract for Arbitrum Stylus
//
// This example demonstrates how to build a Stylus smart contract in Zig that
// follows standard Solidity ABI encoding. Unlike the basic prime-checker demo
// which uses raw bytes, this contract uses proper 4-byte function selectors
// and ABI-encoded uint256 parameters.
//
// Compatible with standard Ethereum tooling (ethers.js, viem, cast):
//
//   cast call <addr> "getCount()(uint256)"
//   cast send <addr> "increment()"
//   cast send <addr> "setCount(uint256)" 42
//
// Function selectors are computed at compile time via keccak256, so there is
// zero runtime overhead for ABI dispatch.

const std = @import("std");

// -- Stylus VM host-io hooks --
pub extern "vm_hooks" fn read_args(dest: *u8) void;
pub extern "vm_hooks" fn write_result(data: *const u8, len: usize) void;
pub extern "vm_hooks" fn storage_load_bytes32(key: *const u8, dest: *u8) void;
pub extern "vm_hooks" fn storage_store_bytes32(key: *const u8, value: *const u8) void;

// -- Comptime function selectors --
// keccak256 first 4 bytes of canonical Solidity signatures.
// Computed entirely at compile time -- no runtime cost.
const SEL_GET_COUNT = comptimeSelector("getCount()");
const SEL_INCREMENT = comptimeSelector("increment()");
const SEL_DECREMENT = comptimeSelector("decrement()");
const SEL_SET_COUNT = comptimeSelector("setCount(uint256)");
const SEL_ADD = comptimeSelector("add(uint256)");

// Storage slot for the counter value (slot 0)
const COUNTER_SLOT: [32]u8 = [_]u8{0} ** 32;

// -- Storage helpers --

fn storageLoad(key: *const [32]u8) [32]u8 {
    var dest: [32]u8 = undefined;
    storage_load_bytes32(@ptrCast(key), @ptrCast(&dest));
    return dest;
}

fn storageStore(key: *const [32]u8, value: *const [32]u8) void {
    storage_store_bytes32(@ptrCast(key), @ptrCast(value));
}

fn getCounter() u256 {
    const raw = storageLoad(&COUNTER_SLOT);
    return std.mem.readInt(u256, &raw, .big);
}

fn setCounter(value: u256) void {
    var buf: [32]u8 = undefined;
    std.mem.writeInt(u256, &buf, value, .big);
    storageStore(&COUNTER_SLOT, &buf);
}

// -- ABI helpers --

fn decodeUint256(calldata: []const u8, offset: usize) u256 {
    if (calldata.len < offset + 32) return 0;
    return std.mem.readInt(u256, calldata[offset..][0..32], .big);
}

fn encodeUint256(value: u256) [32]u8 {
    var buf: [32]u8 = undefined;
    std.mem.writeInt(u256, &buf, value, .big);
    return buf;
}

// -- Main entrypoint --
// Dispatches based on the 4-byte function selector in the calldata.

export fn user_entrypoint(len: usize) i32 {
    if (len < 4) return 1; // Need at least a function selector

    // Read calldata into stack buffer (max 36 bytes: 4 selector + 32 arg)
    var input: [36]u8 = [_]u8{0} ** 36;
    read_args(@ptrCast(&input));

    const selector: [4]u8 = input[0..4].*;

    if (std.mem.eql(u8, &selector, &SEL_GET_COUNT)) {
        const result = encodeUint256(getCounter());
        write_result(@ptrCast(&result), 32);
        return 0;
    }

    if (std.mem.eql(u8, &selector, &SEL_INCREMENT)) {
        setCounter(getCounter() + 1);
        return 0;
    }

    if (std.mem.eql(u8, &selector, &SEL_DECREMENT)) {
        const count = getCounter();
        if (count == 0) return 1;
        setCounter(count - 1);
        return 0;
    }

    if (std.mem.eql(u8, &selector, &SEL_SET_COUNT)) {
        setCounter(decodeUint256(&input, 4));
        return 0;
    }

    if (std.mem.eql(u8, &selector, &SEL_ADD)) {
        setCounter(getCounter() + decodeUint256(&input, 4));
        return 0;
    }

    return 1; // Unknown selector
}

// ============================================================================
// Comptime keccak256-based selector computation
// ============================================================================
//
// Self-contained keccak256 that runs entirely at compile time.
// The selectors are embedded as constants in the WASM binary with zero
// runtime overhead.

fn comptimeSelector(comptime signature: []const u8) [4]u8 {
    comptime {
        const hash = keccak256(signature);
        return hash[0..4].*;
    }
}

fn keccak256(comptime data: []const u8) [32]u8 {
    comptime {
        @setEvalBranchQuota(100_000);

        const RC = [24]u64{
            0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
            0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
            0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
            0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
            0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a,
            0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
        };
        const ROTC = [24]u6{ 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44 };
        const PI = [24]u5{ 10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1 };

        const rate = 136;
        const padded_len = ((data.len + 1 + rate - 1) / rate) * rate;
        var padded: [padded_len]u8 = [_]u8{0} ** padded_len;
        for (data, 0..) |b, i| padded[i] = b;
        padded[data.len] = 0x01;
        padded[padded_len - 1] |= 0x80;

        var state: [25]u64 = [_]u64{0} ** 25;
        var offset: usize = 0;
        while (offset < padded_len) : (offset += rate) {
            for (0..17) |i| {
                var word: u64 = 0;
                for (0..8) |bi| {
                    word |= @as(u64, padded[offset + i * 8 + bi]) << @intCast(bi * 8);
                }
                state[i] ^= word;
            }

            for (0..24) |round| {
                var c: [5]u64 = undefined;
                for (0..5) |x| c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
                for (0..5) |x| {
                    const d = c[(x + 4) % 5] ^ std.math.rotl(u64, c[(x + 1) % 5], 1);
                    for (0..5) |y| state[x + y * 5] ^= d;
                }
                var last = state[1];
                for (0..24) |i| {
                    const j = PI[i];
                    const temp = state[j];
                    state[j] = std.math.rotl(u64, last, ROTC[i]);
                    last = temp;
                }
                for (0..5) |y| {
                    var t: [5]u64 = undefined;
                    for (0..5) |x| t[x] = state[y * 5 + x];
                    for (0..5) |x| state[y * 5 + x] = t[x] ^ (~t[(x + 1) % 5] & t[(x + 2) % 5]);
                }
                state[0] ^= RC[round];
            }
        }

        var out: [32]u8 = undefined;
        for (0..4) |i| {
            for (0..8) |bi| {
                out[i * 8 + bi] = @truncate(state[i] >> @intCast(bi * 8));
            }
        }
        return out;
    }
}
