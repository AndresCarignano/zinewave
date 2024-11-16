const std = @import("std");
const c = @cImport({
    @cInclude("alsa/asoundlib.h");
    @cInclude("/home/andy/Programacion/Zig/midizinewave/src/simplemidi.h");
});

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const myAlloc = gpa.allocator();

const sample_rate: f32 = 44100.0;
const buffer_size: usize = sample_rate / 2;
var buffer1: [buffer_size]i16 = undefined;

export fn parseKeyMap(map: *[120]bool) void {
    var keys_pressed = std.ArrayList(f32).init(myAlloc);

    defer keys_pressed.deinit();
    for (map.*, 0..) |value, i| {
        if (value == true) {
            keys_pressed.append(midiNoteToFreq(@intCast(i))) catch unreachable;
        }
    }

    for (keys_pressed.items) |freq| {
        std.debug.print("{d}   |     ", .{freq});
    }
    playFrequencies(&keys_pressed);
}

fn playFrequencies(frequencies: *std.ArrayList(f32)) void {
    // Generate the combined wave
    // Phase accumulators for both frequencies
    if (frequencies.items.len > 0) {
        for (0..buffer_size) |i| {
            var combined_value: f32 = 0.0;

            const amplitude = 0.5; // Control amplitude to prevent clipping

            for (frequencies.items) |freq1| {
                const phase_increment = (2.0 * std.math.pi * freq1) / sample_rate;
                const phase = phase_increment * @as(f32, @floatFromInt(i));

                combined_value += std.math.sin(phase);
            }

            combined_value /= @as(f32, @floatFromInt(frequencies.items.len));

            // Convert to integer sample
            buffer1[i] = @as(i16, @intFromFloat(combined_value * amplitude * 16000.0));
        }
    } else {
        for (0..buffer_size) |i| {
            buffer1[i] = 0;
        }
    }
}

fn drawWave() void {
    const scale = 100;
    for (0..buffer_size) |i| {
        const space = 1;
        const heigth = @divFloor(space * buffer1[i], scale);
        const abs_height = @as(usize, @intCast(@abs(heigth)));

        for (0..abs_height) |_| {
            std.debug.print("#", .{});
        }
        std.debug.print("\n", .{});
    }
}

pub fn midiNoteToFreq(note: i32) f32 {
    const a4 = 440.0;
    const a4NoteNumber = 69.0;
    return a4 * std.math.pow(f32, 2.0, (@as(f32, @floatFromInt(note)) - a4NoteNumber) / 12.0);
}
pub fn main() !void {
    const result = c.start_midi();
    if (result != 0) {
        return error.MidiStartFailed;
    }
    // Open PCM device
    var handle: ?*c.snd_pcm_t = null;
    const device = "default";

    // Try to open the default audio device
    const err = c.snd_pcm_open(&handle, device, c.SND_PCM_STREAM_PLAYBACK, 0);
    if (err < 0) {
        std.debug.print("Error opening PCM device: {s}\n", .{c.snd_strerror(err)});
        return error.PCMOpenFailed;
    }
    defer _ = c.snd_pcm_close(handle);

    // Configure audio parameters
    _ = c.snd_pcm_set_params(
        handle,
        c.SND_PCM_FORMAT_S16_LE, // 16-bit little-endian
        c.SND_PCM_ACCESS_RW_INTERLEAVED, // Interleaved audio data
        1, // 1 channel (mono)
        16000, // 44100 Hz sample rate
        1, // allow resampling
        0, // 0.5s latency
    );
    // Play
    while (true) {
        _ = c.snd_pcm_writei(handle, &buffer1, buffer1.len);
    }
}
