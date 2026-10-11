const std = @import("std");

const Example = struct {
    name: []const u8,
    root: []const u8,
};

const examples = [_]Example{
    .{ .name = "hello", .root = "examples/hello/main.zig" },
    .{ .name = "smile", .root = "examples/smile/main.zig" },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vec = b.addModule("zig2vec", .{
        .root_source_file = b.path("src/root.zig"),
    });

    for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.name,
            .root_source_file = b.path(ex.root),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("zig2vec", vec);
        addRom(b, exe, ex.name);
    }
}

fn addRom(b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8) void {
    const run = b.addRunArtifact(exe);
    const asm_file = run.captureStdOut();

    const lwasm = b.addSystemCommand(&.{ "lwasm", "--format=raw", "--output" });
    const bin = lwasm.addOutputFileArg(b.fmt("{s}.bin", .{name}));
    lwasm.addFileArg(asm_file);

    const asm_dest = b.fmt("{s}.s", .{name});
    const bin_dest = b.fmt("{s}.bin", .{name});
    b.getInstallStep().dependOn(&b.addInstallFile(asm_file, asm_dest).step);
    b.getInstallStep().dependOn(&b.addInstallBinFile(bin, bin_dest).step);
}
