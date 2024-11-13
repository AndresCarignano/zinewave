const std = @import("std");
const c = @cImport({
    @cInclude("alsa/asoundlib.h");
    @cInclude("/home/andy/Programacion/Zig/midizinewave/src/simplemidi.h");
});

fn getSharedValue() i32 {
    _ = c.pthread_mutex_lock(&c.shared.mutex);
    defer _ = c.pthread_mutex_unlock(&c.shared.mutex);
    return c.shared.currentValue;
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
    // var phase2: f32 = 0.0;
    // var phase3: f32 = 0.0;

    // First frequency (C5)
    const freq1 = midiNoteToFreq(getSharedValue());
    std.debug.print("{d}", .{freq1});
    const phase_increment1 = (2.0 * std.math.pi * freq1) / sample_rate;

    for (0..buffer_size) |i| {

        // Generate both waves

        const value1 = std.math.sin(phase1);
        // const value2 = std.math.sin(phase2);
        // const value3 = std.math.sin(phase3);

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
        std.debug.print("integer: {d}\n", .{getSharedValue()});
        try generateWave();
        _ = c.snd_pcm_writei(handle, &buffer1, buffer1.len);
    }
}
