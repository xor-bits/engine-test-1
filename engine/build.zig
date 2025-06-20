const std = @import("std");

pub fn module(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    vulkan: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const static = switch (target.result.os.tag) {
        .wasi, .freestanding => true,
        else => false,
    };

    const root = b.addModule("engine", .{
        .root_source_file = b.path("engine/engine.zig"),
        .target = target,
        .optimize = optimize,
    });
    root.addImport("vulkan", vulkan.root_module);

    const lib = b.addLibrary(.{
        .name = "engine",
        .root_module = root,
        .linkage = if (static) .static else .dynamic,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });
    lib.linkLibC();

    // Vulkan.
    switch (target.result.os.tag) {
        .windows => lib.linkSystemLibrary("vulkan-1"),
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .haiku, .solaris => lib.linkSystemLibrary("vulkan"),
        else => {},
    }

    switch (target.result.os.tag) {
        .windows => lib.linkSystemLibrary("user32"),
        .linux => lib.linkSystemLibrary("X11"),
        else => {},
    }

    lib.addRPath(.{ .cwd_relative = "$ORIGIN" });

    if (!static) {
        const inst = b.addInstallArtifact(lib, .{
            .dest_dir = .{ .override = .bin },
            .dest_sub_path = b.fmt("bin/{s}", .{lib.out_filename}),
        });
        b.getInstallStep().dependOn(&inst.step);
    }

    return lib;
}
