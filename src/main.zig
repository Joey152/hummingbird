usingnamespace @import("./c.zig");

const graphics = @import("./graphics.zig");
const linmath = @import("./linmath.zig");
const sound = @import("./sound.zig");
const std = @import("std");
const window = @import("./window.zig");

const Mat4 = linmath.Mat4;
const Vec3 = linmath.Vec3;

var prng = std.rand.DefaultPrng.init(0);

pub fn main() !void {
    try window.init();
    defer window.deinit();

    try graphics.init();
    defer graphics.deinit();

    const camera_pos = Vec3.init(0.0, 0.0, 0.0);
    const camera_direction = Vec3.init(0.0, 0.0, 1.0);

    var ubo = graphics.UBO {
        .view = Mat4.view(camera_pos, camera_direction),
        .proj = Mat4.perspective(16.0/9.0, 90.0 * std.math.pi / 180.0, 0.01, 10.0),
        //.proj = Mat4.identity(),
    };

    try sound.init();

    //while (true) {
        //try graphics.drawFrame(&ubo);
    //}
}

