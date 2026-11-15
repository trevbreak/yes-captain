#!/usr/bin/env python3
"""Writes the game's music: a jaunty stride-piano loop in the 1930s cartoon manner (assets/music/shift.wav).

    python3 tools/make_music.py

Everything is synthesized here (a slightly out-of-tune upright piano and a brushed snare), so there are no
samples and nobody's copyright. The tune is original: sixteen bars, written out below, that loop cleanly.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 132
BEAT = 60.0 / BPM
BARS = 16
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "music", "shift.wav")

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    """'C4' -> 261.6"""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12.0)


CHORDS = {
    "C": (["C2", "G2"], ["E3", "G3", "C4"]),
    "C7": (["C2", "E2"], ["E3", "G3", "A#3"]),
    "F": (["F2", "C2"], ["F3", "A3", "C4"]),
    "Fm": (["F2", "C2"], ["F3", "G#3", "C4"]),
    "G7": (["G2", "D2"], ["F3", "G3", "B3"]),
    "D7": (["D2", "A2"], ["F#3", "A3", "C4"]),
    "A7": (["A2", "E2"], ["G3", "A3", "C#4"]),
}
PROG = ["C", "C", "F", "C", "C", "A7", "D7", "G7", "C", "C7", "F", "Fm", "C", "G7", "C", "G7"]

# the right hand: (beat within the bar, note, length in beats) per bar. Syncopated, as ragtime should be.
TUNE = [
    [(0, "E5", .5), (.5, "G5", .5), (1, "C6", 1), (2.5, "A5", .5), (3, "G5", 1)],
    [(0, "E5", .5), (.5, "G5", 1), (1.5, "E5", .5), (2, "C5", 1.5)],
    [(0, "F5", .5), (.5, "A5", .5), (1, "C6", 1), (2.5, "D6", .5), (3, "C6", 1)],
    [(0, "G5", 1.5), (1.5, "E5", .5), (2, "G5", .5), (2.5, "E5", .5), (3, "C5", 1)],
    [(0, "E5", .5), (.5, "G5", .5), (1, "C6", 1), (2.5, "E6", .5), (3, "D6", 1)],
    [(0, "C#6", 1), (1, "A5", .5), (1.5, "G5", 1), (2.5, "E5", .5), (3, "A5", 1)],
    [(0, "F#5", .5), (.5, "A5", .5), (1, "C6", 1), (2, "D6", .5), (2.5, "C6", .5), (3, "A5", 1)],
    [(0, "B5", 1), (1, "G5", .5), (1.5, "F5", .5), (2, "D5", 2)],
    [(0, "C6", .5), (.5, "E6", .5), (1, "G6", 1), (2.5, "E6", .5), (3, "C6", 1)],
    [(0, "A#5", 1.5), (1.5, "G5", .5), (2, "E5", .5), (2.5, "G5", .5), (3, "A#5", 1)],
    [(0, "A5", .5), (.5, "C6", .5), (1, "F6", 1), (2.5, "C6", .5), (3, "A5", 1)],
    [(0, "G#5", .5), (.5, "C6", .5), (1, "F6", 1), (2, "D#6", .5), (2.5, "C6", .5), (3, "G#5", 1)],
    [(0, "G5", .5), (.5, "C6", .5), (1, "E6", 1.5), (2.5, "D6", .5), (3, "C6", 1)],
    [(0, "B5", .5), (.5, "D6", .5), (1, "F6", 1), (2, "D6", .5), (2.5, "B5", .5), (3, "G5", 1)],
    [(0, "C6", 1), (1, "E5", .5), (1.5, "G5", .5), (2, "C6", 2)],
    [(0, "G5", .5), (.5, "A5", .5), (1, "B5", .5), (1.5, "D6", .5), (2, "G5", 1), (3, "G4", 1)],
]


def piano(buf, t0, f, dur, vol, rng):
    """One note of a tired upright: a few harmonics, two strings a hair apart, a quick thump and a long fade."""
    n0 = int(t0 * RATE)
    length = int(min(dur * BEAT + 0.9, 2.6) * RATE)
    detune = 1.0 + rng.uniform(-0.0025, 0.0025)
    hold = dur * BEAT
    for i in range(length):
        idx = (n0 + i) % len(buf)       # notes ringing past the end wrap round, so the loop has no seam
        t = i / RATE
        env = (1.0 - math.exp(-t * 260.0)) * math.exp(-t * (2.6 + f / 420.0))
        if t > hold:
            env *= math.exp(-(t - hold) * 9.0)
        v = 0.0
        for h, a in ((1, 1.0), (2, 0.48), (3, 0.26), (4, 0.13), (5, 0.07)):
            v += a * math.sin(math.tau * f * h * t)
            v += a * 0.6 * math.sin(math.tau * f * h * detune * 1.004 * t)
        buf[idx] += v * env * vol


def brush(buf, t0, vol, rng):
    n0 = int(t0 * RATE)
    lp = 0.0
    for i in range(int(0.11 * RATE)):
        t = i / RATE
        lp += (rng.uniform(-1, 1) - lp) * 0.55
        buf[(n0 + i) % len(buf)] += lp * vol * math.exp(-t * 34.0)


def main():
    rng = random.Random(1932)
    total = int(BARS * 4 * BEAT * RATE)
    buf = [0.0] * total
    for bar in range(BARS):
        bass, chord = CHORDS[PROG[bar]]
        b0 = bar * 4 * BEAT
        swing = 0.035
        # left hand: oom-pah. bass on 1 and 3, the chord on 2 and 4
        piano(buf, b0, hz(bass[0]), 0.9, 0.34, rng)
        piano(buf, b0 + 2 * BEAT, hz(bass[1]), 0.9, 0.30, rng)
        for beat in (1, 3):
            for nt in chord:
                piano(buf, b0 + beat * BEAT + rng.uniform(0, 0.008), hz(nt), 0.45, 0.13, rng)
            brush(buf, b0 + beat * BEAT, 0.10, rng)
        # right hand
        for (beat, nt, ln) in TUNE[bar]:
            late = swing if (beat * 2) % 2 == 1 else 0.0
            piano(buf, b0 + beat * BEAT + late + rng.uniform(0, 0.006), hz(nt), ln * 0.9, 0.20, rng)
            if ln >= 1 and bar % 2 == 0:
                piano(buf, b0 + beat * BEAT + late, hz(nt) / 2.0, ln * 0.9, 0.07, rng)
    peak = max(abs(v) for v in buf) or 1.0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v / peak * 0.86)) * 32767)) for v in buf))
    print("music: %.1f s, %d KB" % (total / RATE, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
