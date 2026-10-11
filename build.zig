const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const emit_exe = b.addExecutable(.{
        .name = "emit",
        .root_source_file = b.path("src/emit.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_emit = b.addRunArtifact(emit_exe);
    const asm_file = run_emit.captureStdOut();

    const lwasm = b.addSystemCommand(&.{ "lwasm", "--format=raw", "--output" });
    const bin = lwasm.addOutputFileArg("game.bin");
    lwasm.addFileArg(asm_file);

    b.getInstallStep().dependOn(&b.addInstallFile(asm_file, "game.s").step);
    b.getInstallStep().dependOn(&b.addInstallBinFile(bin, "game.bin").step);
}
