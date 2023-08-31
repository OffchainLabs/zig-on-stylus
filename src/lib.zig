const std = @import("std");
const WasmAllocator = @import("WasmAllocator.zig");

// External imports provided to all WASM programs on Stylus. These functions
// can be use to read input arguments coming into the program and output arguments to callers.
pub extern "vm_hooks" fn read_args(dest: *u8) void;
pub extern "vm_hooks" fn write_result(data: *const u8, len: usize) void;

// Uses our custom WasmAllocator which is a simple modification over the wasm allocator
// from the Zig standard library as of Zig 0.11.0.
pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &WasmAllocator.vtable,
};

// Reads input arguments from an external, WASM import into a dynamic slice.
pub fn args(len: usize) ![]u8 {
    var input = try allocator.alloc(u8, len);
    read_args(@ptrCast(*u8, input));
    return input;
}

// Outputs data as bytes via a write_result, external WASM import.
pub fn output(data: []u8) void {
    write_result(@ptrCast(*u8, data), data.len);
}

// The main entrypoint to use for execution of the Stylus WASM program.
export fn user_entrypoint(len: usize) i32 {
    // Expects the input is a u16 encoded as little endian bytes.
    var input = args(len) catch return 1;
    var check_nth_prime = std.mem.readIntSliceLittle(u16, input);
    const limit: u16 = 10_000;
    if (check_nth_prime > limit) {
        @panic("input is greater than limit of 10,000 primes");
    }
    // Checks if the number is prime and returns a boolean using the output function.
    var is_prime = sieve_of_erathosthenes(limit, check_nth_prime);
    var out = input[0..1];
    if (is_prime) {
        out[0] = 1;
    } else {
        out[0] = 0;
    }
    output(out);
    return 0;
}

// Uses the sieve algorithm to compute the first N primes. We output these
// to a fixed-size array, with a size determined at compile time. To check
// whether or not a number is prime, just pass in the number and receive a boolean output.
fn sieve_of_erathosthenes(comptime limit: usize, nth: u16) bool {
    var prime = [_]bool{true} ** limit;
    prime[0] = false;
    prime[1] = false;
    var i: usize = 2;
    while (i * i < limit) : (i += 1) {
        if (prime[i]) {
            var j = i * i;
            while (j < limit) : (j += i)
                prime[j] = false;
        }
    }
    return prime[nth];
}
