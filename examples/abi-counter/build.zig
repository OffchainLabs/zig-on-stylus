const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const lib = b.addExecutable(.{
        .name = "abi-counter",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = .ReleaseSmall,
            .target = target,
        }),
    });
    lib.entry = .disabled;
    lib.root_module.export_symbol_names = &.{"user_entrypoint"};
    b.installArtifact(lib);
}
