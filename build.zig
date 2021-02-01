const std = @import("std");
const path = std.fs.path;
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("flicker", "src/main.zig");
    exe.setBuildMode(mode);

    exe.setMainPkgPath("src/");

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("xcb");
    exe.linkSystemLibrary("alsa");
    exe.linkSystemLibrary("vulkan");
    try add_shader(b, exe, "main/shader.vert", "main/vert.spv");
    try add_shader(b, exe, "main/shader.frag", "main/frag.spv");
    exe.install();

    const play = b.step("play", "Play the game");
    const run = exe.run();
    run.step.dependOn(b.getInstallStep());
    play.dependOn(&run.step);
}

fn add_shader(b: *Builder, exe: anytype, in_file: []const u8, out_file: []const u8) !void {
    const dir_name = "asset/shader";
    const in_path = try path.join(b.allocator, &[_][]const u8{ dir_name, in_file });
    const out_path = try path.join(b.allocator, &[_][]const u8{ dir_name, out_file });

    const shader_cmd = b.addSystemCommand(&[_][]const u8 {
        "glslc",
        "-o",
        out_path,
        in_path,
    });

    exe.step.dependOn(&shader_cmd.step);
}

