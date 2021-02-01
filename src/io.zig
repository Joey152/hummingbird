const std = @import("std");

/// Allocator needs to be u32 aligned
pub fn readSPIRV(dir: std.fs.Dir, relative_path: []const u8, allocator: *std.mem.Allocator) !([]align(@alignOf(u32)) u8) {
    var file = try dir.openFile(relative_path, .{});
    defer file.close();

    // TODO: does openFile lock the file? is there a race condition? does size need to be rechecked?
    const size = try file.getEndPos();
    // TODO: invalid u64 cast?
    const buffer = try allocator.alignedAlloc(u8, @alignOf(u32), @intCast(usize, size));
    _ = try file.reader().readAll(buffer);

    return buffer;
}

