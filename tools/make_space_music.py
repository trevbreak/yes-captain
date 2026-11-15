#!/usr/bin/env python3
"""Writes the in-mission music: "Theremin Matinee" (assets/music/mission.wav).

    python3 tools/make_space_music.py

A 1950s sci-fi picture-house tune: a wobbly theremin over a walking bass, celesta sparkles and brushed drums,
with a little echo. Sixteen bars in D minor that loop with no seam (notes ringing past the end wrap round to
the start). Everything is synthesized here and the tune is original, so there are no samples and nobody's
copyright. The menus keep the stride piano (tools/make_music.py).
"""
import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 108
BEAT = 60.0 / BPM
BARS = 16
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "music", "mission.wav")

NOTE = {"C": 0, "C#": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "Bb": 10, "B": 11}


def hz(name):
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12.0)


CHORDS = [["D", "F", "A"], ["D", "F", "A"], ["G", "Bb", "D"], ["A", "C#", "E"],
          ["F", "A", "C"], ["G", "Bb", "D"], ["Bb", "D", "F"], ["A", "C#", "E"],
          ["Bb", "D", "F"], ["F", "A", "C"], ["G", "Bb", "D"], ["A", "C#", "E"],
          ["D", "F", "A"], ["Bb", "D", "F"], ["G", "Bb", "D"], ["A", "C#", "E"]]
ROOTS = ["D2", "D2", "G2", "A2", "F2", "G2", "Bb2", "A2", "Bb2", "F2", "G2", "A2", "D2", "Bb2", "G2", "A2"]
# walking bass: semitones above the bar's root, one per beat
WALK = [[0, 7, 10, 7], [0, 4, 7, 9], [0, 7, 3, 2], [0, 7, 4, 1],
        [0, 4, 7, 4], [0, 3, 7, 3], [0, 4, 7, 5], [0, 7, 4, -1],
        [0, 4, 7, 4], [0, 7, 9, 7], [0, 3, 7, 3], [0, 4, 7, 1],
        [0, 3, 7, 9], [0, 4, 7, 4], [0, 3, 7, 2], [0, 7, 4, 1]]
MELODY = [("A4", 1.5), ("F4", .5), ("D4", 1), ("E4", 1), ("F4", 1), ("G4", 1), ("A4", 2),
          ("Bb4", 1.5), ("A4", .5), ("G4", 1), ("F4", 1), ("E4", 3), (None, 1),
          ("D5", 1.5), ("C5", .5), ("A4", 2), ("Bb4", 1), ("A4", 1), ("G4", 2),
          ("F4", 1), ("E4", 1), ("D4", 1), ("C#4", 1), ("D4", 3), (None, 1),
          ("D5", 2), ("C5", 1), ("Bb4", 1), ("A4", 3), ("F4", 1),
          ("G4", 1.5), ("A4", .5), ("Bb4", 1), ("G4", 1), ("A4", 4),
          ("F5", 1.5), ("E5", .5), ("D5", 2), ("D5", 1), ("C5", 1), ("Bb4", 2),
          ("A4", 1), ("G4", 1), ("E4", 1), ("C#4", 1), ("D4", 3), (None, 1)]


def put(buf, t0, samples):
    i0 = int(t0 * RATE)
    n = len(buf)
    for i, v in enumerate(samples):
        buf[(i0 + i) % n] += v


def bass(f, dur, vol):
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        e = math.exp(-t * 3.2) * min(1.0, t * 200.0) * min(1.0, (dur - t) * 60.0)
        out.append(vol * e * (math.sin(math.tau * f * t) + 0.35 * math.sin(2 * math.tau * f * t) + 0.12 * math.sin(3 * math.tau * f * t)))
    return out


def celesta(f, vol, dur=1.4):
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        e = math.exp(-t * 3.5) * min(1.0, t * 400.0)
        out.append(vol * e * (math.sin(math.tau * f * t) + 0.25 * math.sin(math.tau * 4.0 * f * t) * math.exp(-t * 9)))
    return out


def brush(vol, rng, dur=0.12):
    out = []
    lp = 0.0
    for i in range(int(dur * RATE)):
        lp += (rng.uniform(-1, 1) - lp) * 0.6
        out.append(vol * lp * math.exp(-(i / RATE) * 28.0))
    return out


def theremin(buf, notes, vol, glide=0.09):
    """a legato line with portamento between notes and a singing vibrato"""
    n = len(buf)
    t = 0.0
    ph = 0.0
    cur = None
    for name, beats in notes:
        dur = beats * BEAT
        target = hz(name) if name else None
        if cur is None:
            cur = target
        i0 = int(t * RATE)
        for i in range(int(dur * RATE)):
            if target is None:
                break
            tt = i / RATE
            f = cur + (target - cur) * min(1.0, tt / glide)
            vib = 1.0 + 0.012 * math.sin(math.tau * 6.2 * (t + tt)) * min(1.0, tt / 0.25)
            ph += math.tau * f * vib / RATE
            e = min(1.0, tt / 0.06) * min(1.0, (dur - tt) / 0.08)
            buf[(i0 + i) % n] += vol * e * (math.sin(ph) + 0.18 * math.sin(2 * ph) + 0.06 * math.sin(3 * ph))
        if target is not None:
            cur = target
        t += dur


def echo(buf, delay, fb, mix):
    """a feedback echo that wraps round the loop, run twice so the tail at the end feeds the start"""
    n = len(buf)
    d = int(delay * RATE)
    wet = buf[:]
    for _ in range(2):
        for i in range(n):
            wet[i] = buf[i] + wet[(i - d) % n] * fb
    return [a * (1 - mix) + b * mix for a, b in zip(buf, wet)]


def main():
    rng = random.Random(3)
    buf = [0.0] * int(round(BARS * 4 * BEAT * RATE))
    for b in range(BARS):
        t = b * 4 * BEAT
        root = hz(ROOTS[b])
        for q in range(4):
            put(buf, t + q * BEAT, bass(root * 2 ** (WALK[b][q] / 12.0), BEAT * 0.95, 0.42))
        for q in (1, 3):
            for k, nm in enumerate(CHORDS[b]):
                put(buf, t + q * BEAT + k * 0.03, celesta(hz(nm + "5"), 0.07))
        put(buf, t + 3.5 * BEAT, celesta(hz(CHORDS[b][rng.randrange(3)] + "6"), 0.05))
        for q in range(4):
            put(buf, t + q * BEAT, brush(0.10 if q % 2 else 0.06, rng))
            put(buf, t + (q + 0.66) * BEAT, brush(0.05, rng, 0.08))
    theremin(buf, MELODY, 0.30)
    buf = echo(buf, BEAT * 0.75, 0.32, 0.35)
    peak = max(abs(v) for v in buf)
    k = 0.85 / peak
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * k * 32767)) for v in buf))
    print("wrote %s (%.1f s)" % (os.path.normpath(OUT), len(buf) / RATE))


if __name__ == "__main__":
    main()
