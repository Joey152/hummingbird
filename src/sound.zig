usingnamespace @import("./c.zig");

const std = @import("std");

const allocator = std.heap.c_allocator;

var err: c_int = 0;
var pcm: ?*snd_pcm_t = null;
var hwparams: ?*snd_pcm_hw_params_t = null;
var swparams: ?*snd_pcm_sw_params_t = null;

pub fn init() !void {

    err = snd_pcm_sw_params_malloc(&swparams);
    std.debug.assert(err == 0);

    err = snd_pcm_open(&pcm, "default", .SND_PCM_STREAM_PLAYBACK, 0);
    if (err < 0) {
        return error.PCM_ERROR;
    }
    defer _ = snd_pcm_close(pcm);

    err = snd_pcm_hw_params_malloc(&hwparams);
    std.debug.assert(err == 0);
    err = snd_pcm_hw_params_any(pcm, hwparams);
    if (err < 0) {
        std.debug.print("Cannot set default hardware parameters: {}\n", .{snd_strerror(err)});
    }
    err = snd_pcm_hw_params_set_access(pcm, hwparams, .SND_PCM_ACCESS_RW_INTERLEAVED);
    std.debug.assert(err == 0);
    err = snd_pcm_hw_params_set_format(pcm, hwparams, .SND_PCM_FORMAT_FLOAT_LE);    
    std.debug.assert(err == 0);
    err = snd_pcm_hw_params_set_channels(pcm, hwparams, 2);
    std.debug.assert(err == 0);
    const expected_rate: c_uint = 3520;
    var rate = expected_rate;
    var dir: c_int = 1;
    err = snd_pcm_hw_params_set_rate_near(pcm, hwparams, &rate, &dir);
    std.debug.assert(err == 0);
    var period_size: snd_pcm_uframes_t = 32;
    err = snd_pcm_hw_params_set_period_size_near(pcm, hwparams, &period_size, &dir);
    std.debug.assert(err == 0);
    err = snd_pcm_hw_params(pcm, hwparams);
    std.debug.assert(err == 0);

    var period_time: snd_pcm_uframes_t = 0;
    err = snd_pcm_hw_params_get_period_size(hwparams, &period_time, &dir);
    std.debug.assert(err == 0);

    var buffer_s: snd_pcm_uframes_t = 0;
    err = snd_pcm_hw_params_get_buffer_size(hwparams, &buffer_s);
    std.debug.assert(err == 0);

    // play for 5 seconds
    std.debug.print("period size: {} time: {}\n", .{period_size, period_time});
    std.debug.print("buffer: {}\n", .{buffer_s});
    var loops = 500000 / period_time;

    var buffer_size: usize = period_size * 2;
    var buffer = try allocator.alloc(f32, buffer_size);
    var i: u32 = 0;
    while (i < loops) : (i += 1) {
        var begin = period_size * i;
        var end = begin + period_size;
        getSineWave(rate, 440, begin, end, buffer);
        var frames = snd_pcm_writei(pcm, buffer.ptr, period_size);
        if (frames < 0) {
            std.debug.print("hello\n", .{});
            frames = snd_pcm_recover(pcm, @intCast(c_int, frames), 0);
        }
    }
}

fn getSineWave(sample_rate: u32, freq: u32, begin: u64, end: u64, buffer: []f32) void {
    std.debug.assert(begin <= end);
    std.debug.assert(buffer.len == (end - begin) * 2);

    var b = @intToFloat(f32, begin);
    var e = @intToFloat(f32, end);

    var i: u64 = 0;
    var x = b;
    while (x < e) : ({x += 1; i += 2;}) {
        changeBuffer(buffer, i, x);
    }

    i = 1;
    x = b;
    while (x < e) : ({x += 1; i += 2;}) {
        changeBuffer(buffer, i, x);
    }
}

const a = 440.0 * 2.0 * std.math.pi / 44100.0;
fn changeBuffer(buffer: []f32, i: u64, x: f32) void {
    const m = @mod(x, 8.0);
    if (m == 0.0 or m == 4.0) {
        buffer[i] = 0.0;
    } else if (m == 1.0 or m == 3.0) {
        buffer[i] = std.math.sin(@floatCast(f32, std.math.pi/4.0)); 
    } else if (m == 2.0) {
        buffer[i] = std.math.sin(@floatCast(f32, std.math.pi/2.0)); 
    } else if (m == 5.0 or m == 7.0) {
        buffer[i] = std.math.sin(@floatCast(f32, 5.0*std.math.pi/4.0)); 
    } else if (m == 6.0) {
        buffer[i] = std.math.sin(@floatCast(f32, 3.0*std.math.pi/2.0)); 
    } else {
        unreachable;
    }
}
