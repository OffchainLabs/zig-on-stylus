const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const assert = std.debug.assert;
const wasm = std.wasm;
const math = std.math;

// Instead of the built-in, @wasmMemoryGrow function, Stylus programs need to grow their memory
// via an external import called memory_grow from a group called vm_hooks.
pub extern "vm_hooks" fn memory_grow(len: u32) void;

comptime {
    if (!builtin.target.isWasm()) {
        @compileError("WasmPageAllocator is only available for wasm32 arch");
    }
}

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

pub const Error = Allocator.Error;

const max_usize = math.maxInt(usize);
const ushift = math.Log2Int(usize);
const bigpage_size = 64 * 1024;
const pages_per_bigpage = bigpage_size / wasm.page_size;
const bigpage_count = max_usize / bigpage_size;

/// Because of storing free list pointers, the minimum size class is 3.
const min_class = math.log2(math.ceilPowerOfTwoAssert(usize, 1 + @sizeOf(usize)));
const size_class_count = math.log2(bigpage_size) - min_class;
/// 0 - 1 bigpage
/// 1 - 2 bigpages
/// 2 - 4 bigpages
/// etc.
const big_size_class_count = math.log2(bigpage_count);

var next_addrs = [1]usize{0} ** size_class_count;
/// For each size class, points to the freed pointer.
var frees = [1]usize{0} ** size_class_count;
/// For each big size class, points to the freed pointer.
var big_frees = [1]usize{0} ** big_size_class_count;

fn alloc(ctx: *anyopaque, len: usize, log2_align: u8, return_address: usize) ?[*]u8 {
    _ = ctx;
    _ = return_address;
    // Make room for the freelist next pointer.
    const alignment = @as(usize, 1) << @intCast(Allocator.Log2Align, log2_align);
    const actual_len = @max(len +| @sizeOf(usize), alignment);
    const slot_size = math.ceilPowerOfTwo(usize, actual_len) catch return null;
    const class = math.log2(slot_size) - min_class;
    if (class < size_class_count) {
        const addr = a: {
            const top_free_ptr = frees[class];
            if (top_free_ptr != 0) {
                const node = @intToPtr(*usize, top_free_ptr + (slot_size - @sizeOf(usize)));
                frees[class] = node.*;
                break :a top_free_ptr;
            }

            const next_addr = next_addrs[class];
            if (next_addr % wasm.page_size == 0) {
                const addr = allocBigPages(1);
                if (addr == 0) return null;
                //std.debug.print("allocated fresh slot_size={d} class={d} addr=0x{x}\n", .{
                //    slot_size, class, addr,
                //});
                next_addrs[class] = addr + slot_size;
                break :a addr;
            } else {
                next_addrs[class] = next_addr + slot_size;
                break :a next_addr;
            }
        };
        return @intToPtr([*]u8, addr);
    }
    const bigpages_needed = bigPagesNeeded(actual_len);
    const addr = allocBigPages(bigpages_needed);
    return @intToPtr([*]u8, addr);
}

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    new_len: usize,
    return_address: usize,
) bool {
    _ = ctx;
    _ = return_address;
    // We don't want to move anything from one size class to another, but we
    // can recover bytes in between powers of two.
    const buf_align = @as(usize, 1) << @intCast(Allocator.Log2Align, log2_buf_align);
    const old_actual_len = @max(buf.len + @sizeOf(usize), buf_align);
    const new_actual_len = @max(new_len +| @sizeOf(usize), buf_align);
    const old_small_slot_size = math.ceilPowerOfTwoAssert(usize, old_actual_len);
    const old_small_class = math.log2(old_small_slot_size) - min_class;
    if (old_small_class < size_class_count) {
        const new_small_slot_size = math.ceilPowerOfTwo(usize, new_actual_len) catch return false;
        return old_small_slot_size == new_small_slot_size;
    } else {
        const old_bigpages_needed = bigPagesNeeded(old_actual_len);
        const old_big_slot_pages = math.ceilPowerOfTwoAssert(usize, old_bigpages_needed);
        const new_bigpages_needed = bigPagesNeeded(new_actual_len);
        const new_big_slot_pages = math.ceilPowerOfTwo(usize, new_bigpages_needed) catch return false;
        return old_big_slot_pages == new_big_slot_pages;
    }
}

inline fn compute_vtable_lookups(ctx: *anyopaque, buf: []u8) void {
    _ = buf;
    _ = ctx;
}

fn free(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    return_address: usize,
) void {
    _ = ctx;
    _ = return_address;
    const buf_align = @as(usize, 1) << @intCast(Allocator.Log2Align, log2_buf_align);
    const actual_len = @max(buf.len + @sizeOf(usize), buf_align);
    const slot_size = math.ceilPowerOfTwoAssert(usize, actual_len);
    const class = math.log2(slot_size) - min_class;
    const addr = @ptrToInt(buf.ptr);
    if (class < size_class_count) {
        const node = @intToPtr(*usize, addr + (slot_size - @sizeOf(usize)));
        node.* = frees[class];
        frees[class] = addr;
    } else {
        const bigpages_needed = bigPagesNeeded(actual_len);
        const pow2_pages = math.ceilPowerOfTwoAssert(usize, bigpages_needed);
        const big_slot_size_bytes = pow2_pages * bigpage_size;
        const node = @intToPtr(*usize, addr + (big_slot_size_bytes - @sizeOf(usize)));
        const big_class = math.log2(pow2_pages);
        node.* = big_frees[big_class];
        big_frees[big_class] = addr;
    }
}

inline fn bigPagesNeeded(byte_count: usize) usize {
    return (byte_count + (bigpage_size + (@sizeOf(usize) - 1))) / bigpage_size;
}

fn allocBigPages(n: usize) usize {
    const pow2_pages = math.ceilPowerOfTwoAssert(usize, n);
    const slot_size_bytes = pow2_pages * bigpage_size;
    const class = math.log2(pow2_pages);

    const top_free_ptr = big_frees[class];
    if (top_free_ptr != 0) {
        const node = @intToPtr(*usize, top_free_ptr + (slot_size_bytes - @sizeOf(usize)));
        big_frees[class] = node.*;
        return top_free_ptr;
    }

    memory_grow(pow2_pages * pages_per_bigpage);
    const addr = @intCast(u32, 1) * wasm.page_size;
    return addr;
}
