#!/usr/bin/env python3
"""
Derive greeter-fprint's fingerprint sounds from Cinnamon's own.

The three sounds are made from Linux Mint's Cinnamon sound set
(/usr/share/mint-artwork/sounds, (C) 2022 Google, CC-BY-4.0), so that they
sit beside plug, unplug and notification as if they belonged there - and are
changed enough not to be mistaken for them:

  fingerprint-success   plug (B5 -> E6) plus a third note, G#6: a rising
                        major arpeggio instead of plug's two-note fourth
  fingerprint-failure   unplug's opening E6, then its A5 raised three
                        semitones to C6: a gentle falling third instead of
                        unplug's fifth
  fingerprint-password  notification's body lowered five semitones to A5,
                        twice at the same pitch: neutral, "your turn"

Every segment that starts inside a sound gets a 6 ms fade-in, so no join
clicks, and each result is scaled to plug.oga's sample peak so the set plays
at Cinnamon's level.

A second set, in login-screen/, is the same sounds 14 dB louder. The greeter
runs as the lightdm user, whose audio session has no saved device volume, so
WirePlumber opens the output at its default of about -24 dB - roughly 18 dB
below a typical user session. The gain is baked into files rather than set as
a stream volume because WirePlumber saves stream volumes per media role, and
all event sounds share one role: a boosted stream would leave every later
event sound boosted as well. 14 dB is the ceiling - the base set peaks near
-15 dBFS, so more would clip.

Requires ffmpeg with the rubberband filter, python3-numpy and the
mint-artwork package. Writes to data/sounds/ unless given another directory.
"""

import math
import os
import subprocess
import sys

import numpy as np

SOURCE = "/usr/share/mint-artwork/sounds/"
RATE = 48000
LOGIN_SCREEN_GAIN_DB = 14


def segment(name, start, end, semitones=0.0):
    af = f"atrim={start}:{end},asetpts=PTS-STARTPTS"
    if semitones:
        af += f",rubberband=pitch={2 ** (semitones / 12):.6f}:pitchq=quality"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", SOURCE + name, "-af", af,
                          "-ar", str(RATE), "-ac", "2", "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def fade_in(x, ms):
    n = min(len(x), int(RATE * ms / 1000))
    x[:n] *= np.linspace(0, 1, n)[:, None]
    return x


def fade_out(x, ms):
    n = min(len(x), int(RATE * ms / 1000))
    x[-n:] *= np.linspace(1, 0, n)[:, None]
    return x


def place(parts):
    end = max(int(t * RATE) + len(x) for t, x, _ in parts)
    out = np.zeros((end, 2), dtype=np.float32)
    for t, x, gain in parts:
        i = int(t * RATE)
        out[i:i + len(x)] += x * gain
    return out


def peak_db(x):
    return 20 * math.log10(np.abs(x).max() + 1e-12)


def write(out_dir, name, x, target_db):
    x = fade_out(x * 10 ** ((target_db - peak_db(x)) / 20), 20)
    path = os.path.join(out_dir, name + ".oga")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
                   input=x.astype(np.float32).tobytes(), check=True)
    print(path)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "data", "sounds")
    os.makedirs(out_dir, exist_ok=True)

    target = peak_db(segment("plug.oga", 0, 0.73))

    plug = segment("plug.oga", 0, 0.73)
    third = fade_in(segment("plug.oga", 0.12, 0.73, semitones=4), 6)
    success = place([(0, plug, 1.0), (0.24, third, 0.9)])

    first = fade_out(segment("unplug.oga", 0, 0.13), 12)
    second = fade_in(segment("unplug.oga", 0.12, 0.72, semitones=3), 6)
    failure = place([(0, first, 1.0), (0.12, second, 1.0)])

    tone = fade_in(segment("notification.oga", 0.03, 0.82, semitones=-5), 6)
    password = place([(0, tone, 1.0), (0.16, tone.copy(), 0.7)])

    login_dir = os.path.join(out_dir, "login-screen")
    os.makedirs(login_dir, exist_ok=True)
    for directory, level in [(out_dir, target), (login_dir, target + LOGIN_SCREEN_GAIN_DB)]:
        write(directory, "fingerprint-success", success, level)
        write(directory, "fingerprint-failure", failure, level)
        write(directory, "fingerprint-password", password, level)


if __name__ == "__main__":
    main()
