#!/usr/bin/env python3
"""Synthesise every sound in the game from code, deterministically.

Usage: tools/make_audio.py [--out assets]
Writes assets/sfx/*.ogg and assets/music/*.ogg (via ffmpeg). Pure synthesis:
square/triangle/noise voices with envelopes, no samples, no generative tools,
so the Steam AI-content answer for audio stays "none". Re-run after editing a
recipe; the files are committed so the engine never needs this script.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 22050


# ---------- voices ----------

def t(dur):
    return np.arange(int(SR * dur)) / SR


def square(freq, dur, duty=0.5, sweep=0.0):
    tt = t(dur)
    f = freq * (1.0 + sweep * tt / max(dur, 1e-6))
    phase = np.cumsum(f) / SR
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def triangle(freq, dur):
    tt = t(dur)
    phase = (freq * tt) % 1.0
    return 4.0 * np.abs(phase - 0.5) - 1.0


def sine(freq, dur, sweep=0.0):
    tt = t(dur)
    f = freq * (1.0 + sweep * tt / max(dur, 1e-6))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur, seed=1):
    rng = np.random.default_rng(seed)
    return rng.uniform(-1, 1, int(SR * dur))


def env(dur, a=0.005, d=0.05, s=0.6, r=0.1):
    n = int(SR * dur)
    out = np.ones(n)
    na, nd, nr = int(SR * a), int(SR * d), int(SR * r)
    na, nd, nr = min(na, n), min(nd, n), min(nr, n)
    if na:
        out[:na] = np.linspace(0, 1, na)
    if nd:
        out[na:na + nd] = np.linspace(1, s, nd)[: max(0, n - na)][:nd]
        out[na + nd:] = s
    if nr:
        out[n - nr:] *= np.linspace(1, 0, nr)
    return out


def lowpass(x, alpha=0.2):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*clips, gap=0.0):
    g = np.zeros(int(SR * gap))
    out = []
    for c in clips:
        out.append(c)
        out.append(g)
    return np.concatenate(out)


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


# ---------- sfx recipes ----------

def click():
    return norm(mix(square(1800, 0.03, 0.3) * env(0.03, 0.001, 0.02, 0.0, 0.01),
                    noise(0.02, 2) * env(0.02, 0.001, 0.01, 0.0, 0.01) * 0.4), 0.5)


def chime():
    a = sine(880, 0.18) * env(0.18, 0.003, 0.08, 0.4, 0.08)
    b = sine(1320, 0.22) * env(0.22, 0.003, 0.1, 0.4, 0.1)
    return norm(seq(a * 0.8, b, gap=0.0), 0.6)


def chime_big():
    notes = [660, 880, 1100, 1320]
    parts = [sine(f, 0.12) * env(0.12, 0.003, 0.05, 0.5, 0.05) for f in notes]
    tail = sine(1760, 0.35) * env(0.35, 0.005, 0.15, 0.3, 0.2)
    return norm(seq(*parts, tail, gap=0.0), 0.65)


def error():
    # The three-note "chord" of a classic error: descending, slightly detuned squares.
    a = square(520, 0.22, 0.5) * env(0.22, 0.002, 0.1, 0.5, 0.1)
    b = square(392, 0.26, 0.5) * env(0.26, 0.002, 0.1, 0.5, 0.12)
    c = square(329, 0.32, 0.5) * env(0.32, 0.002, 0.12, 0.5, 0.15)
    return norm(lowpass(seq(a, b, c, gap=0.0), 0.5), 0.55)


def multiply():
    return norm(mix(square(300, 0.25, 0.5, sweep=1.5) * env(0.25, 0.002, 0.1, 0.6, 0.1),
                    square(302, 0.25, 0.5, sweep=1.5) * env(0.25, 0.002, 0.1, 0.6, 0.1)), 0.5)


def hop():
    return norm(sine(500, 0.12, sweep=1.2) * env(0.12, 0.002, 0.05, 0.5, 0.05), 0.45)


def rise():
    # A rising alarm tone for RAM pressure; the engine pitches it by fill level.
    return norm(triangle(440, 0.4) * env(0.4, 0.01, 0.2, 0.7, 0.15), 0.4)


def warn():
    return norm(seq(square(880, 0.08, 0.25) * env(0.08, 0.002, 0.04, 0.5, 0.03),
                    square(880, 0.08, 0.25) * env(0.08, 0.002, 0.04, 0.5, 0.03), gap=0.06), 0.5)


def crash():
    body = lowpass(noise(0.9, 3), 0.08) * env(0.9, 0.005, 0.3, 0.4, 0.5)
    thump = sine(60, 0.5, sweep=-0.8) * env(0.5, 0.002, 0.2, 0.3, 0.3)
    return norm(mix(body, thump * 1.5), 0.8)


def fanfare():
    notes = [523, 659, 784, 1047]
    parts = [mix(square(f, 0.14, 0.5), triangle(f / 2, 0.14) * 0.6) * env(0.14, 0.003, 0.05, 0.6, 0.05) for f in notes]
    hold = mix(square(1047, 0.5, 0.5), square(784, 0.5, 0.5), triangle(523, 0.5)) * env(0.5, 0.005, 0.2, 0.5, 0.3)
    return norm(lowpass(seq(*parts, hold, gap=0.02), 0.6), 0.6)


def shutdown():
    notes = [784, 659, 523, 392]
    parts = [mix(sine(f, 0.3), sine(f * 2, 0.3) * 0.3) * env(0.3, 0.01, 0.1, 0.6, 0.2) for f in notes]
    return norm(seq(*parts, gap=0.0), 0.55)


def dialup():
    # Dial tone, DTMF-ish touches, carrier negotiation, white hiss. Short: 2.4 s.
    tone = mix(sine(350, 0.5), sine(440, 0.5)) * env(0.5, 0.01, 0.1, 0.8, 0.05)
    digits = seq(*[mix(sine(f1, 0.08), sine(f2, 0.08)) * env(0.08, 0.002, 0.02, 0.8, 0.02)
                   for f1, f2 in [(697, 1209), (770, 1336), (852, 1477), (941, 1336), (697, 1477)]], gap=0.04)
    carrier = mix(square(1200, 0.5, 0.5) * 0.5, square(2250, 0.5, 0.5) * 0.3) * env(0.5, 0.01, 0.2, 0.7, 0.1)
    warble = sine(1800, 0.4, sweep=-0.4) * env(0.4, 0.01, 0.1, 0.8, 0.1)
    hiss = lowpass(noise(0.5, 5), 0.4) * env(0.5, 0.05, 0.2, 0.7, 0.2) * 0.6
    return norm(lowpass(seq(tone, digits, carrier, warble, hiss, gap=0.03), 0.7), 0.5)


def typewriter():
    return norm(mix(square(2400, 0.02, 0.2) * env(0.02, 0.001, 0.01, 0.0, 0.01),
                    noise(0.015, 7) * env(0.015, 0.001, 0.005, 0.0, 0.01) * 0.5), 0.4)


def crunch():
    # Paper crumple for "Empty Recycle Bin": 0.35 s of band-passed noise (a light
    # low-pass minus a heavy one leaves the papery mid band) with a few crackle
    # transients at fixed offsets.
    dur = 0.35
    n = noise(dur, 17)
    body = (lowpass(n, 0.45) - lowpass(n, 0.08)) * env(dur, 0.01, 0.12, 0.5, 0.15)
    out = body * 0.7
    for at, length, seed in [(0.03, 0.012, 21), (0.09, 0.008, 22), (0.14, 0.015, 23), (0.21, 0.01, 24), (0.27, 0.012, 25)]:
        crack = noise(length, seed) * env(length, 0.0005, 0.004, 0.2, 0.005)
        start = int(SR * at)
        out[start:start + len(crack)] += crack * 1.2
    return norm(out, 0.55)


# ---------- music ----------

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name):
    if name == "-":
        return 0.0
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] - 9) / 12 + (octave - 4))


def voice(notes, step, wave_fn, vol, duty=0.5):
    out = []
    for n in notes:
        f = freq(n)
        dur = step
        if f == 0.0:
            out.append(np.zeros(int(SR * dur)))
            continue
        w = wave_fn(f, dur, duty) if wave_fn is square else wave_fn(f, dur)
        out.append(w * env(dur, 0.004, step * 0.3, 0.5, step * 0.25) * vol)
    return np.concatenate(out)


def drums(pattern, step):
    out = []
    for ch in pattern:
        n = int(SR * step)
        if ch == "k":
            out.append(sine(90, step, sweep=-0.7)[:n] * env(step, 0.001, 0.08, 0.0, 0.05) * 0.9)
        elif ch == "s":
            out.append(lowpass(noise(step, 11), 0.5)[:n] * env(step, 0.001, 0.06, 0.0, 0.05) * 0.5)
        elif ch == "h":
            out.append(noise(step, 13)[:n] * env(step, 0.001, 0.02, 0.0, 0.02) * 0.25)
        else:
            out.append(np.zeros(n))
    return np.concatenate(out)


def music_desk():
    """Upbeat 8-bar loop in C major, 150 bpm, eighth-note steps. The office at 9 AM."""
    step = 60 / 150 / 2
    lead = ("E5 G5 E5 C5 D5 E5 - G5  A5 G5 E5 C5 D5 - E5 -  "
            "F5 A5 F5 D5 E5 F5 - A5  G5 F5 E5 D5 C5 - - -  "
            "E5 G5 E5 C5 D5 E5 - G5  A5 G5 E5 C5 D5 - E5 -  "
            "G5 A5 B5 G5 A5 B5 C6 -  B5 A5 G5 E5 C5 - - -").split()
    bass = ("C3 - C3 - G2 - C3 -  A2 - A2 - E2 - A2 -  "
            "F2 - F2 - C3 - F2 -  G2 - G2 - D3 - G2 -  "
            "C3 - C3 - G2 - C3 -  A2 - A2 - E2 - A2 -  "
            "F2 - F2 - C3 - F2 -  G2 - D3 - G2 - B2 -").split()
    arp = ("C4 E4 G4 E4 C4 E4 G4 E4  A3 C4 E4 C4 A3 C4 E4 C4  "
           "F3 A3 C4 A3 F3 A3 C4 A3  G3 B3 D4 B3 G3 B3 D4 B3  "
           "C4 E4 G4 E4 C4 E4 G4 E4  A3 C4 E4 C4 A3 C4 E4 C4  "
           "F3 A3 C4 A3 F3 A3 C4 A3  G3 B3 D4 B3 G3 B3 D4 B3").split()
    dr = "khshkhsh" * 8
    m = mix(voice(lead, step, square, 0.35, 0.25), voice(bass, step, triangle, 0.5),
            voice(arp, step, square, 0.12, 0.5), drums(dr, step))
    return norm(lowpass(m, 0.55), 0.6)


def music_menu():
    """Slow 4-bar loop in A minor, 90 bpm, quarter-note steps. The boot screen."""
    step = 60 / 90
    lead = "A4 - C5 - E5 - D5 -  C5 - B4 - A4 - - -  F4 - A4 - C5 - B4 -  G4 - E4 - A4 - - -".split()
    pad = "A3 A3 A3 A3 A3 A3 A3 A3  F3 F3 F3 F3 G3 G3 G3 G3  F3 F3 F3 F3 F3 F3 F3 F3  E3 E3 E3 E3 E3 E3 E3 E3".split()
    m = mix(voice(lead, step, triangle, 0.45), voice(pad, step, square, 0.12, 0.5))
    return norm(lowpass(m, 0.35), 0.5)


# ---------- output ----------

def write_ogg(path, samples, loop=False):
    data = np.clip(samples, -1, 1)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((data * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.unlink(tmp.name)
    print(f"{path:32} {len(samples) / SR:5.2f}s{'  loop' if loop else ''}")


def main():
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "assets"
    os.makedirs(f"{out}/sfx", exist_ok=True)
    os.makedirs(f"{out}/music", exist_ok=True)
    for name, fn in [("click", click), ("chime", chime), ("chime_big", chime_big), ("error", error),
                     ("multiply", multiply), ("hop", hop), ("rise", rise), ("warn", warn), ("crash", crash),
                     ("fanfare", fanfare), ("shutdown", shutdown), ("dialup", dialup), ("typewriter", typewriter),
                     ("crunch", crunch)]:
        write_ogg(f"{out}/sfx/{name}.ogg", fn())
    write_ogg(f"{out}/music/desk.ogg", music_desk(), loop=True)
    write_ogg(f"{out}/music/menu.ogg", music_menu(), loop=True)


if __name__ == "__main__":
    main()
