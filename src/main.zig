const std = @import("std");
const c = @cImport({
    @cInclude("alsa/asoundlib.h");
    @cInclude("/home/andy/Programacion/Zig/midizinewave/src/simplemidi.h");
});

fn getSharedValue() *[120]bool {
    _ = c.pthread_mutex_lock(&c.keydata.mutex);
    defer _ = c.pthread_mutex_unlock(&c.keydata.mutex);
    return &c.keydata.keys;
}
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const myAlloc = gpa.allocator();

export fn parseKeyMap(map: *[120]bool) void {
    var keys_pressed = std.ArrayList(f32).init(myAlloc);

    defer keys_pressed.deinit();
    for (map.*, 0..) |value, i| {
        if (value == true) {
            keys_pressed.append(midiNoteToFreq(@intCast(i))) catch unreachable;
        }
    }

    while (keys_pressed.items.len > 0) {
        std.debug.print("{d}   |     ", .{keys_pressed.pop()});
    }
}

fn playFrequencies(frequencies: std.ArrayList(f32)) void {
    buffer1 = undefined;
    // Generate the combined wave
    // Phase accumulators for both frequencies
    var phase1: f32 = 0.0;

    while (frequencies.items.len > 0) {
        const freq1 = frequencies.pop();

        const phase_increment1 = (2.0 * std.math.pi * freq1) / sample_rate;

        for (0..buffer_size) |i| {

            // Generate both waves

            const value1 = std.math.sin(phase1);

            // Mix the waves (average them and adjust amplitude)

            const combined_value = (value1) * 0.33;
            //
            // if (i > buffer_size / 3) {
            //     combined_value = (value1 + value2) * 0.33;
            // }
            //
            // if (i > (buffer_size * 2) / 3) {
            //     combined_value = (value1 + value2 + value3) * 0.33;
            // }

            // Convert to integer sample
            buffer1[i] = @as(i16, @intFromFloat(combined_value * 16000.0));

            // Increment phases
            phase1 += phase_increment1;
            // phase2 += phase_increment2;
            // phase3 += phase_increment3;

            // Keep phases in reasonable range
            if (phase1 > 2.0 * std.math.pi) {
                phase1 -= 2.0 * std.math.pi;
            }
        }
    }
}

pub fn midiNoteToFreq(note: i32) f32 {
    const a4 = 440.0;
    const a4NoteNumber = 69.0;
    return a4 * std.math.pow(f32, 2.0, (@as(f32, @floatFromInt(note)) - a4NoteNumber) / 12.0);
}

const sample_rate: f32 = 44100.0;
const buffer_size: usize = sample_rate / 2;
var buffer1: [buffer_size]i16 = undefined;

pub fn generateWave() !void {
    buffer1 = undefined;
    // Generate the combined wave
    // Phase accumulators for both frequencies
    var phase1: f32 = 0.0;

    const freq1 = 100;

    const phase_increment1 = (2.0 * std.math.pi * freq1) / sample_rate;

    for (0..buffer_size) |i| {

        // Generate both waves

        const value1 = std.math.sin(phase1);

        // Mix the waves (average them and adjust amplitude)

        const combined_value = (value1) * 0.33;
        //
        // if (i > buffer_size / 3) {
        //     combined_value = (value1 + value2) * 0.33;
        // }
        //
        // if (i > (buffer_size * 2) / 3) {
        //     combined_value = (value1 + value2 + value3) * 0.33;
        // }

        // Convert to integer sample
        buffer1[i] = @as(i16, @intFromFloat(combined_value * 16000.0));

        // Increment phases
        phase1 += phase_increment1;
        // phase2 += phase_increment2;
        // phase3 += phase_increment3;

        // Keep phases in reasonable range
        if (phase1 > 2.0 * std.math.pi) {
            phase1 -= 2.0 * std.math.pi;
        }
    }
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
        44100, // 44100 Hz sample rate
        1, // allow resampling
        0, // 0.5s latency
    );
    // Play
    while (true) {
        // std.debug.print("integer: {d}\n", .{getSharedValue()});
        try generateWave();
        _ = c.snd_pcm_writei(handle, &buffer1, buffer1.len);
    }
}
