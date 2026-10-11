const std = @import("std");
const builtin = @import("builtin");

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

    const launch_flag = b.option(bool, "launch", "Open the ROM in RetroArch after a local macOS build. Default: true on macOS outside CI.");
    const rom_name = b.option([]const u8, "rom", "Which ROM to open locally. Default: smile.") orelse "smile";
    const launch = launch_flag orelse defaultLaunch();

    if (launch) {
        var known = false;
        for (examples) |ex| {
            if (std.mem.eql(u8, ex.name, rom_name)) known = true;
        }
        if (!known) {
            std.debug.panic("-Drom={s} does not match an example", .{rom_name});
        }
    }

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
        const open = launch and std.mem.eql(u8, ex.name, rom_name);
        addRom(b, exe, ex.name, open);
    }
}

fn defaultLaunch() bool {
    if (std.posix.getenv("CI") != null) return false;
    if (std.posix.getenv("GITHUB_ACTIONS") != null) return false;
    return builtin.os.tag == .macos;
}

fn addRom(b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8, launch: bool) void {
    const run = b.addRunArtifact(exe);
    const asm_file = run.captureStdOut();

    const lwasm = b.addSystemCommand(&.{ "lwasm", "--format=raw", "-o" });
    const bin = lwasm.addOutputFileArg(b.fmt("{s}.bin", .{name}));
    lwasm.addFileArg(asm_file);

    const asm_dest = b.fmt("{s}.s", .{name});
    const bin_dest = b.fmt("{s}.bin", .{name});
    const install_bin = b.addInstallBinFile(bin, bin_dest);
    b.getInstallStep().dependOn(&b.addInstallFile(asm_file, asm_dest).step);
    b.getInstallStep().dependOn(&install_bin.step);

    if (!launch) return;

    const open = b.addSystemCommand(&.{ "sh", "tools/launch-mac.sh" });
    open.addArg(b.getInstallPath(.bin, bin_dest));
    open.step.dependOn(&install_bin.step);
    b.getInstallStep().dependOn(&open.step);
}
