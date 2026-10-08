"""Original lo-fi background track for the launch video (no samples, no licensing).

Warm Rhodes-like chords, a soft sub bass, a gentle plucked arpeggio, a muted kick and swung hats,
all synthesised with numpy. Writes ../public/music.wav.
"""
import wave
from pathlib import Path

import numpy as np

SR = 44_100
BPM = 84
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 16  # about 45 s
LENGTH = int(BAR * BARS * SR) + SR * 3
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def lowpass(x, cutoff):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    spectrum *= 1 / np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(x))


def env(n, attack, release, sustain=None):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    if sustain is None:
        return a * np.exp(-t / release)
    return a * np.where(t < sustain, 1.0, np.exp(-(t - sustain) / release))


def add(track, sound, at):
    i = int(at * SR)
    j = min(len(track), i + len(sound))
    track[i:j] += sound[: j - i]


# Fmaj9 · Em7 · Dm9 · Cmaj7 (low voicings, lots of space)
CHORDS = [
    [53, 57, 60, 64, 67],
    [52, 55, 59, 62, 67],
    [50, 53, 57, 60, 64],
    [48, 52, 55, 59, 64],
]
BASS = [41, 40, 38, 36]

chords = np.zeros(LENGTH)
bass = np.zeros(LENGTH)
pluck = np.zeros(LENGTH)
drums = np.zeros(LENGTH)

for bar in range(BARS):
    start = bar * BAR
    notes = CHORDS[bar % 4]
    n = int(BAR * SR * 1.1)
    t = np.arange(n) / SR
    # Electric-piano-ish tone: sine plus a little bell partial, slight detune, slow tremolo.
    for k, note in enumerate(notes):
        f = midi(note) * (1 + rng.uniform(-0.002, 0.002))
        tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 3)
        tone *= env(n, 0.02, 1.4, sustain=BAR * 0.8) * (1 + 0.08 * np.sin(2 * np.pi * 4.5 * t))
        add(chords, tone * 0.11, start + k * 0.012)
    # Sub bass on beats 1 and 3.
    for beat in (0, 2):
        m = int(BEAT * 1.9 * SR)
        tb = np.arange(m) / SR
        b = np.sin(2 * np.pi * midi(BASS[bar % 4]) * tb) * env(m, 0.01, 0.6, sustain=BEAT * 1.2)
        add(bass, b * 0.32, start + beat * BEAT)
    # Plucked arpeggio from bar 3, eighth notes with a lazy swing.
    if bar >= 2:
        pattern = [notes[2] + 12, notes[3] + 12, notes[4] + 12, notes[3] + 12, notes[1] + 12, notes[3] + 12, notes[4] + 12, notes[2] + 24]
        for i, note in enumerate(pattern):
            if rng.random() < 0.2:
                continue
            at = start + i * BEAT / 2 + (0.035 if i % 2 else 0)
            m = int(0.9 * SR)
            tp = np.arange(m) / SR
            p = (np.sin(2 * np.pi * midi(note) * tp) + 0.3 * np.sin(2 * np.pi * 3 * midi(note) * tp)) * env(m, 0.003, 0.22)
            add(pluck, p * 0.07 * rng.uniform(0.7, 1.0), at)
    # Drums from bar 5: soft kick, rim on 2 and 4, swung closed hats.
    if bar >= 4 and bar < BARS - 1:
        for beat in (0, 2.5):
            m = int(0.35 * SR)
            tk = np.arange(m) / SR
            k = np.sin(2 * np.pi * (48 + 70 * np.exp(-tk * 30)) * tk) * np.exp(-tk * 9)
            add(drums, k * 0.5, start + beat * BEAT)
        for beat in (1, 3):
            m = int(0.12 * SR)
            r = rng.normal(0, 1, m) * np.exp(-np.arange(m) / SR * 45)
            add(drums, lowpass(r, 3500) * 0.12, start + beat * BEAT)
        for i in range(8):
            m = int(0.05 * SR)
            h = rng.normal(0, 1, m) * np.exp(-np.arange(m) / SR * 90)
            h = h - lowpass(h, 6000)
            add(drums, h * (0.05 if i % 2 else 0.035), start + i * BEAT / 2 + (0.04 if i % 2 else 0))

chords = lowpass(chords, 2200)
pluck = lowpass(pluck, 4500)

# A small room: convolve the melodic parts with a short decaying-noise impulse response.
ir_len = int(1.6 * SR)
ir = rng.normal(0, 1, ir_len) * np.exp(-np.arange(ir_len) / SR * 3.2)
ir = lowpass(ir, 3000)
ir /= np.abs(ir).sum() / 3
wet_in = chords + pluck
wet = np.fft.irfft(np.fft.rfft(wet_in, LENGTH + ir_len) * np.fft.rfft(ir, LENGTH + ir_len))[:LENGTH]

mix = chords + pluck + bass + drums + 0.35 * wet
# Vinyl-ish bed of very quiet filtered noise.
mix += lowpass(rng.normal(0, 1, LENGTH), 1800) * 0.004

t = np.arange(LENGTH) / SR
mix *= np.clip(t / 1.5, 0, 1)
end = BAR * BARS
mix *= np.clip((end + 2.5 - t) / 3.0, 0, 1)
mix = np.tanh(mix * 1.4) / np.tanh(1.4)
mix *= 0.85 / np.abs(mix).max()

stereo = np.stack([mix, np.roll(mix, int(0.011 * SR))], axis=1)
pcm = (stereo * 32767).astype(np.int16)
out = Path(__file__).resolve().parent.parent / "public" / "music.wav"
with wave.open(str(out), "wb") as f:
    f.setnchannels(2)
    f.setsampwidth(2)
    f.setframerate(SR)
    f.writeframes(pcm.tobytes())
print(out, f"{LENGTH / SR:.1f}s")
