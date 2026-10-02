#!/usr/bin/env python3
"""Procedural placeholder audio for "Mise en Chaos".

Every sound effect and music loop in ``audio/sfx`` and ``audio/music`` is
synthesized from scratch here with numpy/scipy DSP: oscillators, filtered
noise, modal (struck-object) resonators, FM, simple vocal formant synthesis,
envelopes and a convolution reverb.  No samples, no external audio sources.
All randomness uses fixed seeds, so the output is reproducible.

Run from the repository root::

    python3 tools/audio/generate_audio.py              # regenerate everything, then verify
    python3 tools/audio/generate_audio.py --sfx        # only sound effects
    python3 tools/audio/generate_audio.py --music      # only music
    python3 tools/audio/generate_audio.py --only ding,coin,stem_base
    python3 tools/audio/generate_audio.py --verify     # only check the existing files
    python3 tools/audio/generate_audio.py --list       # list asset names

Requirements: Python 3.9+, numpy, scipy, and ffmpeg built with libvorbis
(the music is written as Ogg Vorbis).

Conventions
-----------
* SFX: 16-bit PCM mono WAV, 44.1 kHz.  Names ending in ``_loop`` are seamless
  loops (built circularly: events wrap around the loop end, noise beds are
  filtered in the frequency domain, tones use whole periods).
* Music: Ogg Vorbis (q5), 44.1 kHz stereo.  Every track is exactly 16 bars,
  rendered circularly (note tails and reverb wrap to the start), so it loops
  seamlessly.  The three ``stem_*`` files share tempo, progression and sample
  length and are meant to be layered.
"""
from __future__ import annotations

import argparse
import math
import shutil
import subprocess
import sys
import time
import wave
import zlib
from pathlib import Path

import numpy as np

try:
    from scipy import signal as sps
except ImportError:  # pragma: no cover
    sys.exit("generate_audio.py needs scipy:  pip install numpy scipy")

SR = 44100
TAU = 2.0 * np.pi
ROOT = Path(__file__).resolve().parents[2]
SFX_DIR = ROOT / "audio" / "sfx"
MUSIC_DIR = ROOT / "audio" / "music"


# =============================================================================
# Basic helpers
# =============================================================================

def ns(seconds):
    """Seconds -> number of samples."""
    return max(1, int(round(seconds * SR)))


def tvec(n):
    return np.arange(n) / SR


def rng_for(name, salt=0):
    """Deterministic RNG per asset (crc32 is stable across runs/platforms)."""
    return np.random.default_rng(zlib.crc32(name.encode()) + salt)


def dbg(db):
    """dB -> linear gain."""
    return 10.0 ** (db / 20.0)


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def norm(x, peak=1.0):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def unit(x):
    """Scale to unit standard deviation (for mixing noise beds by RMS)."""
    s = np.std(x)
    return x / s if s > 0 else x


def pad(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def loguniform(rng, lo, hi):
    return float(np.exp(rng.uniform(np.log(lo), np.log(hi))))


def add_at(buf, x, start, gain=1.0, wrap=False):
    """Mix ``x`` into ``buf`` at sample ``start``; with wrap=True it wraps
    around the end of the buffer (used to build seamless loops)."""
    start = int(round(start))
    n = len(buf)
    k = min(len(x) // 4, 110)  # ~2.5 ms raised-cosine tail: no truncation clicks
    if k > 1:
        x = x.copy()
        x[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    if wrap:
        pos = start % n
        x = x * gain
        while len(x):
            k = min(n - pos, len(x))
            buf[pos:pos + k] += x[:k]
            x = x[k:]
            pos = 0
        return buf
    if start < 0:
        x = x[-start:]
        start = 0
    k = min(n - start, len(x))
    if k > 0:
        buf[start:start + k] += gain * x[:k]
    return buf


def at(buf, x, t, gain=1.0, wrap=False):
    """Like add_at but with the start time in seconds."""
    return add_at(buf, x, t * SR, gain, wrap)


# =============================================================================
# Filters
# =============================================================================

def _sos(btype, freq, order):
    nyq = SR / 2.0
    if np.ndim(freq) == 0:
        wn = min(max(freq / nyq, 1e-5), 0.99)
    else:
        wn = [min(max(f / nyq, 1e-5), 0.99) for f in freq]
    return sps.butter(order, wn, btype=btype, output="sos")


def lp(x, fc, order=2):
    return sps.sosfilt(_sos("lowpass", fc, order), x)


def hp(x, fc, order=2):
    return sps.sosfilt(_sos("highpass", fc, order), x)


def bp(x, lo, hi, order=2):
    return sps.sosfilt(_sos("bandpass", (lo, hi), order), x)


def rbj(kind, f0, q=0.707, gain_db=0.0):
    """RBJ cookbook biquad coefficients."""
    w0 = TAU * min(max(f0, 10.0), SR * 0.45) / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * q)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":  # constant 0 dB peak gain
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        A = 10 ** (gain_db / 40.0)
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    else:
        raise ValueError(kind)
    return np.array(b) / a[0], np.array(a) / a[0]


def biquad(x, kind, f0, q=0.707, gain_db=0.0):
    b, a = rbj(kind, f0, q, gain_db)
    return sps.lfilter(b, a, x)


def sweep(x, kind, f_arr, q=0.707, block=64):
    """Time-varying biquad (coefficients updated every ``block`` samples)."""
    f_arr = np.broadcast_to(np.asarray(f_arr, float), x.shape)
    y = np.empty_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), block):
        j = min(i + block, len(x))
        b, a = rbj(kind, float(f_arr[(i + j - 1) // 2]), q)
        y[i:j], zi = sps.lfilter(b, a, x[i:j], zi=zi)
    return y


def cfilt(x, lo=None, hi=None, order=2):
    """Zero-phase *circular* Butterworth-magnitude filter done with an FFT.
    Because it is circular, a loop stays perfectly seamless after filtering."""
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1.0 / SR)
    H = np.ones_like(f)
    if hi is not None:
        H /= np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo is not None:
        H /= np.sqrt(1.0 + (lo / np.maximum(f, 1e-9)) ** (2 * order))
        H[0] = 0.0
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * H, n, axis=-1)


def cconv(x, ir):
    """Circular convolution: a reverb tail that runs past the loop end wraps
    around to the loop start (seamless loops)."""
    n = len(x)
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)


# =============================================================================
# Sources: noise, oscillators, envelopes, resonators
# =============================================================================

def white(n, rng):
    return rng.standard_normal(n)


def colored(n, rng, slope_db_per_oct):
    """Circular spectrally-shaped noise (-3 = pink, -6 = brown), unit std."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    X *= (f / 1000.0) ** (slope_db_per_oct / 6.0206)
    X[0] = 0.0
    return unit(np.fft.irfft(X, n))


def slow_noise(n, rng, hz, lo=None):
    """Smooth, *periodic* random modulation signal in [-1, 1]."""
    return norm(cfilt(rng.standard_normal(n), lo=lo, hi=hz, order=3))


def env_perc(n, attack=0.002, decay=0.1):
    """Smooth attack then exponential decay (decay = time constant, s)."""
    t = tvec(n)
    a = smoothstep(t / attack) if attack > 0 else np.ones(n)
    return a * np.exp(-np.maximum(t - attack, 0.0) / decay)


def env_lin(n, points):
    """Piecewise-linear envelope from [(time_s, value), ...]."""
    ts, vs = zip(*points)
    return np.interp(tvec(n), ts, vs)


def phase_of(freq, n=None):
    """Integrated phase (radians) of a (possibly time-varying) frequency."""
    f = np.full(n, float(freq)) if np.ndim(freq) == 0 else np.asarray(freq, float)
    ph = np.cumsum(f) * (TAU / SR)
    return ph - ph[0]


def additive(freq, amps, n=None, maxf=15000.0):
    """Band-limited additive oscillator: sum_k amps[k-1] * sin(k * phase)."""
    f = np.full(n, float(freq)) if np.ndim(freq) == 0 else np.asarray(freq, float)
    ph = phase_of(f)
    out = np.zeros(len(f))
    for k, a in enumerate(amps, 1):
        if a == 0:
            continue
        fk = f * k
        if np.min(fk) >= maxf:
            break
        g = np.clip((maxf - fk) / (0.15 * maxf), 0.0, 1.0)
        out += a * g * np.sin(k * ph)
    return out


def modal(n, modes, attack=0.0006):
    """Struck-object resonator: sum of exponentially decaying sinusoids.
    modes = [(freq_hz, amplitude, decay_time_constant_s), ...]
    Partials above ~9 kHz are gently attenuated so nothing gets piercing."""
    t = tvec(n)
    out = np.zeros(n)
    for f, a, tau in modes:
        if f >= 16000 or a == 0:
            continue
        a /= math.sqrt(1.0 + (f / 9000.0) ** 4)
        out += a * np.exp(-t / tau) * np.sin(TAU * f * t)
    if attack > 0:
        out *= smoothstep(t / attack)
    return out


def click(n, rng, fc=4000.0, tau=0.0015):
    """Soft transient tick (low-passed noise burst)."""
    return lp(white(n, rng), fc, 2) * env_perc(n, 0.0002, tau)


def thump(n, f_end, start_ratio=1.8, tau=0.08, sweep_tau=0.015):
    """Low sine 'thud' with a fast downward pitch sweep."""
    t = tvec(n)
    f = f_end * (1.0 + (start_ratio - 1.0) * np.exp(-t / sweep_tau))
    return np.sin(phase_of(f)) * env_perc(n, 0.001, tau)


def wood(n, f0, rng, decay=0.04, bright=1.0):
    """Wooden knock (inharmonic plate-ish modes + tick)."""
    ratios = (1.0, 1.62, 2.43, 3.51, 4.9)
    amps = (1.0, 0.6, 0.38, 0.22 * bright, 0.12 * bright)
    modes = [(f0 * r * (1 + 0.01 * rng.standard_normal()), a, decay / (1 + 0.6 * i))
             for i, (r, a) in enumerate(zip(ratios, amps))]
    return modal(n, modes) + 0.25 * bright * click(n, rng, 3500, 0.002)


def ceramic(n, f0, rng, decay=0.25):
    """Plate / cup clink."""
    ratios = (1.0, 1.49, 2.18, 2.87, 3.71)
    amps = (1.0, 0.7, 0.5, 0.33, 0.2)
    modes = [(f0 * r * (1 + 0.008 * rng.standard_normal()), a, decay / (1 + 0.5 * i))
             for i, (r, a) in enumerate(zip(ratios, amps))]
    return modal(n, modes) + 0.2 * click(n, rng, 7000, 0.001)


def metal(n, f0, rng, decay=0.2, ratios=(1.0, 2.76, 5.40, 8.93), amps=(1.0, 0.45, 0.2, 0.08)):
    """Metal bar / tool clank."""
    modes = [(f0 * r * (1 + 0.004 * rng.standard_normal()), a, decay / (1 + 0.8 * i))
             for i, (r, a) in enumerate(zip(ratios, amps))]
    return modal(n, modes) + 0.15 * click(n, rng, 6000, 0.001)


def small_bell(n, f0, decay=0.5):
    """Small brass bell (slightly beating fundamental + inharmonic partials)."""
    modes = [(f0, 1.0, decay), (f0 * 1.0028, 0.5, decay * 0.9), (f0 * 2.04, 0.22, decay * 0.4),
             (f0 * 2.76, 0.3, decay * 0.3), (f0 * 4.1, 0.1, decay * 0.15), (f0 * 5.4, 0.05, decay * 0.1)]
    return modal(n, modes, attack=0.0004)


def glock(n, f0, decay=0.35, vel=1.0):
    """Glockenspiel / chime bar (free-free bar partials)."""
    modes = [(f0, 1.0, decay), (f0 * 2.76, 0.25 * vel, decay * 0.25), (f0 * 5.40, 0.08 * vel, decay * 0.08)]
    return modal(n, modes, attack=0.0005)


def fm_bell(n, f, ratio=3.5, index=1.8, idx_tau=0.15, tau=0.6):
    t = tvec(n)
    idx = index * np.exp(-t / idx_tau) + 0.15
    return np.sin(TAU * f * t + idx * np.sin(TAU * f * ratio * t)) * env_perc(n, 0.001, tau)


def bubble(f0, amp=1.0, xi=0.1):
    """Liquid bubble 'blip' (van den Doel's Minnaert bubble model):
    exponentially decaying sine whose pitch rises as the bubble surfaces."""
    d = 0.13 * f0 + 0.0072 * f0 ** 1.5
    n = ns(min(5.0 / d, 0.25))
    t = tvec(n)
    f = f0 * (1.0 + xi * d * t)
    return amp * np.sin(phase_of(f)) * np.exp(-d * t) * smoothstep(t / 0.0015)


def crackle(rng, f_lo, f_hi, tau=(0.0008, 0.003)):
    """Single crackle/pop: tiny damped resonance plus a noise grain."""
    f = loguniform(rng, f_lo, f_hi)
    tc = rng.uniform(*tau)
    n = ns(tc * 6)
    t = tvec(n)
    x = np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / tc)
    x += 0.5 * white(n, rng) * np.exp(-t / (tc * 0.5))
    return x * smoothstep(t / 0.0002)


def grains(n, rng, count, span, lo, hi, gdur=(0.003, 0.012), amp_tau=None, t0=0.0):
    """Granular rustle: many short noise grains, band-passed."""
    out = np.zeros(n)
    for _ in range(count):
        ti = t0 + rng.random() * span
        gl = max(4, ns(rng.uniform(*gdur)))
        g = white(gl, rng) * np.hanning(gl)
        a = rng.uniform(0.3, 1.0)
        if amp_tau:
            a *= np.exp(-(ti - t0) / amp_tau)
        at(out, g * a, ti)
    return bp(out, lo, hi, 2)


# --- simple vocal (formant) synthesis: used for the crowd and customer sounds --

VOWELS = {  # F1, F2, F3 in Hz
    "a": (730, 1090, 2440), "e": (530, 1840, 2480), "i": (300, 2200, 2900),
    "o": (570, 840, 2410), "u": (325, 870, 2250), "@": (500, 1500, 2500),
}


def voice(f0, formants, amp, bw=(90.0, 110.0, 170.0), gains=(1.0, 0.5, 0.25), tilt=1.0, maxf=4500.0):
    """Additive 'vocal' tone.  f0 and the formants may be per-sample arrays.
    Each harmonic is weighted by a sum-of-Lorentzians spectral envelope."""
    f0 = np.asarray(f0, float)
    n = len(f0)
    ph = phase_of(f0)
    F = [np.broadcast_to(np.asarray(Fi, float), (n,)) for Fi in formants]
    out = np.zeros(n)
    K = int(maxf / max(np.min(f0), 40.0))
    for k in range(1, K + 1):
        fk = k * f0
        g = np.zeros(n)
        for Fi, Bi, Ai in zip(F, bw, gains):
            g += Ai / (1.0 + ((fk - Fi) / Bi) ** 2)
        g *= np.clip((maxf - fk) / 600.0, 0.0, 1.0) / k ** tilt
        out += g * np.sin(k * ph)
    return out * amp


# =============================================================================
# Output: WAV / OGG writers and final processing
# =============================================================================

_DC_SOS = sps.butter(2, 18.0 / (SR / 2.0), "highpass", output="sos")


def trim_tail(x, thresh_db=-60.0):
    a = np.abs(x)
    idx = np.nonzero(a > a.max() * dbg(thresh_db))[0]
    if len(idx) == 0:
        return x
    return x[:min(len(x), idx[-1] + 1 + ns(0.01))]


def finalize_oneshot(x, peak_db=-1.0, fade_in=0.0015, fade_out=0.012):
    """DC-block, trim trailing silence, click-free fades, peak-normalize."""
    x = sps.sosfilt(_DC_SOS, np.asarray(x, float))
    x = trim_tail(x)
    fi = min(ns(fade_in), len(x) // 4)
    fo = min(ns(fade_out), len(x) // 3)
    if fi > 1:
        x[:fi] *= np.sin(np.linspace(0, np.pi / 2, fi)) ** 2
    if fo > 1:
        x[-fo:] *= np.cos(np.linspace(0, np.pi / 2, fo)) ** 2
    return norm(x, dbg(peak_db))


def finalize_loop(x, peak_db=-1.0):
    """Circular DC/sub-sonic removal (keeps the seam intact) + peak-normalize."""
    x = cfilt(np.asarray(x, float), lo=20.0, order=2)
    return norm(x, dbg(peak_db))


def write_wav(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def ffmpeg_bin():
    exe = shutil.which("ffmpeg")
    if not exe:
        sys.exit("ffmpeg (with libvorbis) is required to write the music .ogg files")
    return exe


def write_ogg(path, stereo):
    """stereo: float array (2, n).  Encoded with libvorbis q5."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.ascontiguousarray(stereo.T.astype("<f4"))
    cmd = [ffmpeg_bin(), "-hide_banner", "-loglevel", "error", "-y",
           "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
           "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
           "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path)]
    subprocess.run(cmd, input=data.tobytes(), check=True)


# =============================================================================
# Sound effects.  Each generator takes a seeded RNG and returns a float array.
# =============================================================================

# ---- footsteps / handling ---------------------------------------------------

def footstep(rng, pitch=1.0):
    n = ns(0.16)
    x = 0.9 * thump(n, 92 * pitch, 1.7, tau=0.03, sweep_tau=0.01)
    x += 0.7 * lp(white(n, rng), 1300 * pitch, 2) * env_perc(n, 0.0008, 0.012)
    x += 0.35 * modal(n, [(240 * pitch, 1, 0.025), (410 * pitch, 0.6, 0.018), (690 * pitch, 0.3, 0.01)])
    toe = 0.4 * lp(white(n, rng), 1100 * pitch, 2) * env_perc(n, 0.001, 0.01)
    toe += 0.2 * modal(n, [(300 * pitch, 1, 0.015)])
    at(x, toe, 0.028 + 0.006 * rng.random())
    return lp(x, 2200 * pitch, 2)


def sfx_pickup(rng):
    n = ns(0.2)
    t = tvec(n)
    f = 330 + 560 * (1 - np.exp(-t / 0.045))
    ph = phase_of(f)
    tone = (np.sin(ph) + 0.2 * np.sin(2 * ph) * np.exp(-t / 0.03)) * env_perc(n, 0.004, 0.055)
    air = lp(bp(white(n, rng), 700, 3000), 4000) * env_lin(n, [(0, 0), (0.03, 1), (0.09, 0.2), (0.2, 0)])
    return tone + 0.15 * norm(air)


def sfx_putdown(rng):
    n = ns(0.22)
    x = wood(n, 360, rng, decay=0.05) + 0.5 * thump(n, 120, 1.4, tau=0.035)
    return lp(x, 5000)


def sfx_drop_heavy(rng):
    n = ns(0.6)

    def impact(scale):
        y = thump(n, 52, 2.0, tau=0.13 * scale, sweep_tau=0.018)
        y += 0.7 * norm(bp(white(n, rng), 120, 1400)) * env_perc(n, 0.001, 0.045 * scale)
        y += 0.45 * wood(n, 165, rng, decay=0.09 * scale, bright=0.5)
        return y

    x = impact(1.0)
    at(x, 0.32 * impact(0.6), 0.10)
    at(x, 0.12 * impact(0.4), 0.165)
    return lp(x, 2800)


def sfx_crate_take(rng):
    n = ns(0.32)
    x = 0.8 * norm(grains(n, rng, 28, 0.17, 1200, 5000, amp_tau=0.1))
    at(x, 0.7 * wood(n, 610, rng, decay=0.022, bright=1.2), 0.035)
    at(x, 0.4 * thump(ns(0.1), 150, 1.3, tau=0.03), 0.06)
    return lp(x, 7000)


def chop(rng, pitch=1.0):
    n = ns(0.24)
    x = 0.45 * norm(grains(n, rng, 6, 0.012, 1800, 6500, gdur=(0.002, 0.006)))
    thock = wood(n, 380 * pitch, rng, decay=0.04, bright=1.3) + 0.6 * thump(n, 150 * pitch, 1.5, tau=0.03)
    at(x, thock, 0.008)
    return lp(x, 7500)


# ---- cooking ------------------------------------------------------------------

def sfx_sizzle_loop(rng):
    dur = 2.5
    N = ns(dur)
    hiss = cfilt(white(N, rng), lo=1800, hi=5000, order=3)
    hiss *= (0.75 + 0.25 * slow_noise(N, rng, 4)) * (0.8 + 0.2 * slow_noise(N, rng, 40, lo=12))
    crack = np.zeros(N)
    for _ in range(int(dur * 140)):
        add_at(crack, crackle(rng, 1500, 4500) * rng.exponential(0.3), rng.integers(N), wrap=True)
    fat = np.zeros(N)
    for _ in range(int(dur * 30)):
        add_at(fat, bubble(loguniform(rng, 900, 2500), rng.uniform(0.2, 1.0)), rng.integers(N), wrap=True)
    x = 0.3 * unit(hiss) + 0.5 * crack + 0.35 * fat
    return cfilt(x, hi=6500, order=3)


def sfx_fryer_loop(rng):
    dur = 2.5
    N = ns(dur)
    oil = unit(cfilt(white(N, rng), lo=400, hi=3500)) * (0.7 + 0.3 * slow_noise(N, rng, 8))
    hiss = unit(cfilt(white(N, rng), lo=3000, hi=7000))
    bub = np.zeros(N)
    for _ in range(int(dur * 90)):
        f0 = loguniform(rng, 220, 1400)
        add_at(bub, bubble(f0, rng.uniform(0.2, 1.0) * (300 / f0) ** 0.3), rng.integers(N), wrap=True)
    pops = np.zeros(N)
    for _ in range(int(dur * 12)):
        add_at(pops, crackle(rng, 1500, 5000) * rng.exponential(0.5), rng.integers(N), wrap=True)
    x = 0.1 * oil + 0.03 * hiss + 0.5 * bub + 0.2 * pops
    return cfilt(x, lo=80, hi=6000, order=3)


def sfx_ding(rng):
    n = ns(1.3)
    f = 1318.5  # E6
    x = small_bell(n, f, decay=0.9)
    x += 0.35 * fm_bell(n, f, ratio=3.5, index=1.2, idx_tau=0.08, tau=0.5)
    x += 0.15 * norm(bp(white(n, rng), 2500, 8000)) * env_perc(n, 0.0003, 0.0015)
    return lp(x, 9000)


def sfx_burn_warning(rng):
    n = ns(1.1)
    t = tvec(n)
    hiss = norm(bp(white(n, rng), 250, 2200)) * env_lin(n, [(0, 0), (0.15, 1), (0.8, 0.9), (1.1, 0)])
    hiss *= 0.75 + 0.25 * np.sin(TAU * 5 * t)
    crack = np.zeros(n)
    for _ in range(70):
        ti = 1.0 * math.sqrt(rng.random())  # denser towards the end
        at(crack, crackle(rng, 1200, 4500) * rng.exponential(0.5) * (0.4 + 0.6 * ti), ti)
    for _ in range(8):
        at(crack, crackle(rng, 500, 1200, tau=(0.003, 0.008)) * rng.uniform(0.5, 1.0), rng.uniform(0.1, 1.0))
    tone = np.zeros(n)  # soft worried "uh-oh" (G4 -> E4, sagging)
    for t0, fa, fb, d in [(0.05, 392.0, 380.0, 0.22), (0.31, 330.0, 300.0, 0.42)]:
        m = ns(d)
        tt = tvec(m)
        fr = (fa + (fb - fa) * tt / d) * (1 + 0.012 * np.sin(TAU * 6 * tt))
        ph = phase_of(fr)
        s = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
        s *= env_lin(m, [(0, 0), (0.02, 1), (d - 0.06, 0.8), (d, 0)])
        at(tone, s, t0)
    x = 0.3 * hiss + 0.5 * norm(crack) + 0.4 * norm(lp(tone, 1800))
    return lp(x, 7000)


def sfx_coffee_brew_loop(rng):
    dur = 2.4
    N = ns(dur)
    t = tvec(N)
    ph = TAU * 50.0 * t  # 50 Hz vibratory pump: exactly 120 cycles per loop
    buzz = sum(a * np.sin(k * ph + rng.uniform(0, TAU))
               for k, a in [(1, 0.35), (2, 0.7), (3, 0.6), (4, 0.4), (5, 0.25), (6, 0.15), (8, 0.08)])
    buzz = cfilt(buzz, hi=700) * (0.85 + 0.15 * slow_noise(N, rng, 3))
    gurgle = np.zeros(N)
    centers = [0.3, 1.1, 1.8]
    for _ in range(70):
        c = centers[rng.integers(len(centers))] + rng.normal(0, 0.18)
        f0 = loguniform(rng, 120, 480)
        add_at(gurgle, bubble(f0, rng.uniform(0.3, 1.0), xi=0.15), c * SR, wrap=True)
    stream = unit(cfilt(white(N, rng), lo=500, hi=2600)) * (0.6 + 0.4 * slow_noise(N, rng, 25, lo=6))
    steam = unit(cfilt(white(N, rng), lo=3500, hi=7000))
    x = 0.25 * unit(buzz) + 0.9 * gurgle + 0.15 * stream + 0.025 * steam
    return cfilt(x, lo=70, hi=5000, order=3)


def sfx_coffee_done(rng):
    n = ns(0.85)
    x = np.zeros(n)
    for t0, f, d in [(0.0, 783.99, 0.22), (0.17, 1046.5, 0.45)]:  # G5 -> C6
        m = ns(d + 0.3)
        tt = tvec(m)
        s = (np.sin(TAU * f * tt) + 0.18 * np.sin(TAU * 2 * f * tt) + 0.06 * np.sin(TAU * 3 * f * tt))
        s *= env_perc(m, 0.006, d * 0.6)
        s += 0.12 * np.sin(TAU * 2.76 * f * tt) * env_perc(m, 0.001, 0.05)
        at(x, s, t0)
    return x


def sfx_fridge_open(rng):
    n = ns(1.1)
    t = tvec(n)
    x = 0.4 * norm(bp(white(n, rng), 250, 1100)) * env_lin(n, [(0, 0), (0.04, 0.5), (0.07, 0)])
    m = ns(0.3)
    pop = thump(m, 70, 2.2, tau=0.05, sweep_tau=0.012)
    pop += 0.6 * norm(lp(white(m, rng), 600)) * env_perc(m, 0.001, 0.03)
    at(x, pop, 0.06)
    hum_env = env_lin(n, [(0, 0), (0.15, 0), (0.55, 1), (1.1, 1)])
    ph = TAU * 60.0 * t
    hum = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
    fan = unit(lp(hp(white(n, rng), 120), 900))
    air = norm(bp(white(n, rng), 600, 3500)) * env_lin(n, [(0, 0), (0.08, 0), (0.18, 1), (0.6, 0.3), (1.1, 0.2)])
    x += hum_env * (0.12 * hum + 0.05 * fan) + 0.12 * air
    return x


def sfx_fridge_close(rng):
    n = ns(0.45)
    x = thump(n, 72, 1.8, tau=0.07, sweep_tau=0.015)
    x += 0.6 * norm(lp(white(n, rng), 380)) * env_perc(n, 0.002, 0.04)
    at(x, 0.3 * norm(bp(white(n, rng), 250, 900)) * env_perc(n, 0.004, 0.025), 0.004)
    at(x, 0.12 * modal(ns(0.05), [(1900, 1, 0.006), (3100, 0.5, 0.004)]), 0.018)
    return lp(x, 3500)


# ---- bells, dishes ------------------------------------------------------------

def sfx_door_bell(rng):
    n = ns(1.2)
    x = np.zeros(n)
    hits = [(0.0, 1396.9, 1.0), (0.012, 1760.0, 0.45), (0.11, 2093.0, 0.75),
            (0.125, 1396.9, 0.3), (0.23, 1760.0, 0.55), (0.36, 2093.0, 0.22)]
    for t0, f, a in hits:
        m = n - ns(t0)
        b = small_bell(m, f * (1 + 0.002 * rng.standard_normal()), decay=0.45)
        b += 0.1 * norm(bp(white(m, rng), 3000, 7000)) * env_perc(m, 0.0003, 0.002)
        at(x, a * b, t0)
    return lp(x, 9500)


def sfx_dish_clink(rng):
    n = ns(0.5)
    x = ceramic(n, 2050, rng, decay=0.22)
    at(x, 0.3 * ceramic(n, 2350, rng, decay=0.12), 0.035)
    return lp(x, 9000)


def sfx_dish_stack(rng):
    n = ns(0.75)
    x = np.zeros(n)
    for t0, f, a in [(0.0, 1650, 1.0), (0.045, 2100, 0.6), (0.1, 1850, 0.8), (0.17, 2400, 0.5), (0.26, 1950, 0.4)]:
        m = n - ns(t0)
        f *= 1 + 0.02 * rng.standard_normal()
        c = ceramic(m, f, rng, decay=0.15) + 0.6 * modal(m, [(f * 0.23, 1, 0.02), (f * 0.41, 0.6, 0.015)])
        at(x, a * c, t0)
    x += 0.15 * norm(grains(n, rng, 20, 0.3, 2000, 6000, gdur=(0.002, 0.005), amp_tau=0.15))
    return lp(x, 8500)


# ---- washing ------------------------------------------------------------------

def sfx_wash_loop(rng):
    dur = 2.4
    N = ns(dur)
    water = unit(cfilt(white(N, rng), lo=350, hi=4200))
    water *= 0.6 + 0.4 * np.abs(slow_noise(N, rng, 35, lo=5))
    drops = np.zeros(N)
    for _ in range(int(dur * 120)):
        add_at(drops, bubble(loguniform(rng, 700, 3500), rng.uniform(0.1, 0.6)), rng.integers(N), wrap=True)
    scrub = np.zeros(N)
    for i in range(4):  # 4 brush strokes per loop
        m = ns(0.55)
        tt = tvec(m)
        bristle = 0.65 + 0.35 * norm(lp(white(m, rng), 120))
        s = bp(white(m, rng), 900 if i % 2 else 1300, 4200) * np.sin(np.pi * tt / 0.55) ** 2 * bristle
        add_at(scrub, s, (i * 0.6 + 0.02) * SR, wrap=True)
    sink = unit(cfilt(white(N, rng), lo=120, hi=500))
    x = 0.45 * water + 0.5 * drops + 0.45 * unit(scrub) + 0.15 * sink
    return cfilt(x, hi=5000, order=3)


def sfx_dishwasher_loop(rng):
    dur = 3.0
    N = ns(dur)
    t = tvec(N)
    ph = TAU * 100.0 * t  # whole periods
    hum = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph) + 0.1 * np.sin(4 * ph)
    swish = unit(cfilt(white(N, rng), lo=250, hi=1600))
    swish *= (0.35 + 0.65 * (0.5 + 0.5 * np.sin(TAU * 1.0 * t)) ** 2) * (0.8 + 0.2 * slow_noise(N, rng, 12, lo=3))
    spatter = np.zeros(N)
    for _ in range(int(dur * 60)):
        add_at(spatter, bubble(loguniform(rng, 400, 1800), rng.uniform(0.2, 1.0)), rng.integers(N), wrap=True)
    x = 0.12 * hum + 0.6 * swish + 0.3 * spatter
    return cfilt(x, lo=40, hi=1800)


def sfx_dishwasher_done(rng):
    n = ns(0.95)
    x = np.zeros(n)
    f = 1760.0
    for i in range(3):
        m = ns(0.14)
        tt = tvec(m)
        s = np.sin(TAU * f * tt) + 0.2 * np.sin(TAU * 3 * f * tt)
        s *= env_lin(m, [(0, 0), (0.006, 1), (0.13, 0.9), (0.14, 0)])
        at(x, s, 0.02 + i * 0.28)
    return lp(x, 7000)


# ---- money --------------------------------------------------------------------

def sfx_cash_register(rng):
    n = ns(1.2)
    x = np.zeros(n)
    m = ns(0.12)
    clack = modal(m, [(1250, 1, 0.02), (2650, 0.6, 0.012), (3900, 0.35, 0.008)])
    clack += 0.6 * norm(bp(white(m, rng), 700, 4500)) * env_perc(m, 0.0005, 0.006)
    clack += 0.5 * thump(m, 170, 1.4, tau=0.025)
    at(x, clack, 0.0)
    m = ns(0.13)
    tt = tvec(m)
    slide = norm(bp(white(m, rng), 400, 2500)) * env_lin(m, [(0, 0), (0.02, 1), (0.12, 0.6), (0.13, 0)])
    slide *= 0.7 + 0.3 * np.sin(TAU * 70 * tt)
    at(x, 0.3 * slide, 0.03)
    at(x, 0.5 * thump(ns(0.1), 140, 1.3, tau=0.02) + 0.3 * wood(ns(0.1), 700, rng, decay=0.015), 0.15)
    for t0, f, a in [(0.12, 2217.5, 1.0), (0.128, 3322.4, 0.5)]:
        at(x, a * small_bell(n - ns(t0), f, decay=0.55), t0)
    return lp(x, 10000)


def sfx_coin(rng):
    n = ns(0.55)
    x = modal(n, [(2950, 1, 0.18), (4340, 0.6, 0.12), (6150, 0.3, 0.07), (7900, 0.12, 0.04)])
    x += 0.2 * click(n, rng, 8000, 0.0008)
    at(x, 0.45 * modal(n, [(3070, 1, 0.1), (4500, 0.6, 0.07), (6300, 0.3, 0.04)]), 0.075)
    for t0, f in [(0.03, 1975.5), (0.085, 2637.0)]:  # little B6 -> E7 sparkle
        m = ns(0.25)
        at(x, 0.35 * np.sin(TAU * f * tvec(m)) * env_perc(m, 0.002, 0.07), t0)
    return lp(x, 10000)


def sfx_money_spend(rng):
    n = ns(0.5)
    x = 0.6 * norm(bp(white(n, rng), 1500, 6000)) * env_perc(n, 0.001, 0.012)
    x += 0.35 * norm(bp(white(n, rng), 900, 4500)) * env_lin(n, [(0, 0), (0.01, 0), (0.04, 1), (0.09, 0)])
    at(x, 0.45 * modal(n, [(2700, 1, 0.12), (3970, 0.5, 0.08), (5600, 0.2, 0.04)]), 0.07)
    at(x, 0.3 * modal(n, [(2350, 1, 0.1), (3450, 0.5, 0.06)]), 0.13)
    return lp(x, 9000)


# ---- customers ----------------------------------------------------------------

def _utterance(rng, f0_base, dur):
    """A few unintelligible 'syllables' of formant-synthesized babble."""
    n = ns(dur)
    t = tvec(n)
    nsyl = max(1, int(round(dur * rng.uniform(4.0, 6.0))))
    edges = np.linspace(0, dur, nsyl + 1)
    edges[1:-1] += rng.uniform(-0.25, 0.25, nsyl - 1) * (dur / nsyl)
    centers = 0.5 * (edges[:-1] + edges[1:])
    keys = list(VOWELS)
    vow = [VOWELS[keys[rng.integers(len(keys))]] for _ in range(nsyl)]
    F = [np.interp(t, centers, [v[i] * rng.uniform(0.92, 1.08) for v in vow]) for i in range(3)]
    amp = np.zeros(n)
    for i in range(nsyl):
        s, e = edges[i], edges[i + 1]
        seg = (t >= s) & (t < e)
        amp[seg] = rng.uniform(0.55, 1.0) * np.sin(np.pi * (t[seg] - s) / (e - s)) ** 0.7
    accent = np.interp(t, centers, rng.uniform(-0.06, 0.08, nsyl))
    f0 = f0_base * (1.1 - 0.18 * t / dur) * (1 + accent) * (1 + 0.01 * np.sin(TAU * 5.5 * t))
    x = voice(f0, F, amp, tilt=1.0, maxf=3800)
    for s in edges[:-1]:  # occasional consonant hiss
        if rng.random() < 0.4:
            m = ns(0.03)
            at(x, 0.05 * norm(bp(white(m, rng), 2000, 5000)) * np.hanning(m), s)
    return x * smoothstep(t / 0.02) * smoothstep((dur - t) / 0.03)


def sfx_crowd_loop(rng):
    dur = 4.0
    N = ns(dur)
    x = np.zeros(N)
    for v in range(14):
        f0 = rng.uniform(95, 140) if v % 2 == 0 else rng.uniform(170, 240)
        level = rng.uniform(0.3, 1.0)
        pos = rng.uniform(0, dur)
        covered = 0.0
        while covered < dur * 0.7:
            d = rng.uniform(0.5, 1.6)
            u = _utterance(rng, f0 * rng.uniform(0.95, 1.05), d)
            add_at(x, level * u, pos * SR, wrap=True)
            gap = rng.uniform(0.15, 0.8)
            pos += d + gap
            covered += d + gap
    x = cfilt(x, lo=180, hi=2600, order=2)
    room = make_ir(0.7, 0.55, seed=5, predelay=0.008, bright_hz=3000, dark_hz=1200)[0]
    x = unit(x) + 0.5 * unit(cconv(x, room))
    clinks = np.zeros(N)
    for _ in range(7):
        m = ns(0.3)
        c = ceramic(m, rng.uniform(1700, 2600), rng, decay=rng.uniform(0.08, 0.18))
        add_at(clinks, c * rng.uniform(0.3, 1.0), rng.integers(N), wrap=True)
    clinks = cfilt(clinks, hi=3500, order=3)
    tone = colored(N, rng, -4.5)
    tone = cfilt(tone, lo=60, hi=800)
    return x + 0.1 * norm(clinks) * np.max(np.abs(x)) + 0.08 * unit(tone)


def sfx_customer_happy(rng):
    n = ns(0.45)
    x = np.zeros(n)
    for t0, d, fa, fb, a in [(0.0, 0.13, 390, 430, 0.75), (0.16, 0.24, 440, 660, 1.0)]:  # "mm-HM!"
        m = ns(d)
        tt = tvec(m)
        u = tt / d
        f0 = (fa + (fb - fa) * (1 - (1 - u) ** 2)) * (1 + 0.012 * np.sin(TAU * 7 * tt))
        op = smoothstep((u - 0.2) / 0.6)  # nasal hum opening up slightly
        F = (280 + 180 * op, 1100 + 500 * op, 2500 + 0 * op)
        amp = env_lin(m, [(0, 0), (0.025, 1), (d - 0.04, 0.85), (d, 0)])
        at(x, a * norm(voice(f0, F, amp, gains=(1.0, 0.35, 0.15), tilt=1.2, maxf=5000)), t0)
    return lp(x, 5000)


def sfx_customer_angry(rng):
    n = ns(0.62)
    d = 0.55
    m = ns(d)
    tt = tvec(m)
    u = tt / d
    f0 = 165 * (1 - 0.42 * u ** 0.8) * (1 + 0.03 * np.sin(TAU * 28 * tt))
    F = (520 - 80 * u, 950 - 100 * u, 2300 + 0 * u)
    amp = env_lin(m, [(0, 0), (0.04, 1), (0.4, 0.85), (d, 0)]) * (0.75 + 0.25 * np.sin(TAU * 30 * tt))
    x = norm(voice(f0, F, amp, tilt=1.1, maxf=3500))
    x += 0.08 * norm(bp(white(m, rng), 400, 1800)) * env_lin(m, [(0, 0), (0.02, 1), (0.08, 0)])
    return lp(pad(x, n), 2600)


def sfx_order_ready(rng):
    n = ns(0.42)
    x = np.zeros(n)
    for t0, f, d, a in [(0.0, 1046.5, 0.09, 0.85), (0.085, 1568.0, 0.22, 1.0)]:  # C6 -> G6
        m = ns(d + 0.15)
        tt = tvec(m)
        ph = phase_of(f * (1 - 0.03 * np.exp(-tt / 0.012)))
        s = (np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)) * env_perc(m, 0.003, d * 0.55)
        at(x, a * s, t0)
    return lp(x, 9000)


def sfx_serve(rng):
    n = ns(0.9)
    x = 0.9 * thump(n, 130, 1.5, tau=0.035) + 0.5 * ceramic(n, 950, rng, decay=0.06)
    x += 0.25 * ceramic(n, 2300, rng, decay=0.1)
    for i, f in enumerate((1396.9, 1760.0, 2093.0, 2793.8)):  # F6 A6 C7 F7 sparkle
        t0 = 0.07 + 0.045 * i
        at(x, (0.24 - 0.03 * i) * glock(n - ns(t0), f, decay=0.25), t0)
    x += 0.015 * norm(bp(white(n, rng), 4000, 7000)) * env_lin(n, [(0, 0), (0.08, 0), (0.2, 1), (0.6, 0)])
    return lp(x, 10000)


# ---- delivery truck -----------------------------------------------------------

def sfx_truck_engine_loop(rng):
    dur = 2.0
    N = ns(dur)
    x = np.zeros(N)
    pulses = 48  # 24 Hz firing rate, whole pulses per loop
    cyl = (1.0, 0.82, 0.93, 0.78)
    for k in range(pulses):
        m = ns(0.09)
        tt = tvec(m)
        p = np.sin(TAU * 62 * tt) * np.exp(-tt / 0.028) + 0.7 * np.sin(TAU * 124 * tt + 0.5) * np.exp(-tt / 0.016)
        p += 0.45 * np.sin(TAU * 187 * tt + 0.9) * np.exp(-tt / 0.012)
        p *= smoothstep(tt / 0.002)
        p += 0.35 * norm(bp(white(m, rng), 120, 700)) * np.exp(-tt / 0.02)
        p += 0.35 * np.sin(TAU * 248 * tt + 1.3) * np.exp(-tt / 0.01)  # valve-train 'tick' body
        p += 0.06 * norm(bp(white(m, rng), 900, 2400)) * np.exp(-tt / 0.004)
        add_at(x, cyl[k % 4] * rng.uniform(0.9, 1.1) * p, (k + 0.5) * N / pulses + rng.normal(0, 8), wrap=True)
    rumble = cfilt(colored(N, rng, -6), lo=25, hi=180)
    x = unit(x) + 0.35 * unit(rumble)
    x = cfilt(x, lo=25, hi=1600)
    return np.tanh(1.5 * x / np.max(np.abs(x)))


def sfx_truck_beep(rng):
    m = ns(0.34)
    tt = tvec(m)
    f = 1100.0
    s = np.sin(TAU * f * tt) + 0.22 * np.sin(TAU * 3 * f * tt) + 0.08 * np.sin(TAU * 5 * f * tt)
    s *= env_lin(m, [(0, 0), (0.008, 1), (0.32, 1), (0.34, 0)])
    return lp(pad(s, ns(0.4)), 7000)


def _horn_tone(f, n):
    t = tvec(n)
    fr = f * (1 + 0.04 * np.exp(-t / 0.03)) * (1 + 0.003 * np.sin(TAU * 5.5 * t))
    ph = phase_of(fr)
    out = np.zeros(n)
    for k in range(1, int(5000 / f) + 1):
        fk = k * f
        g = 1 / (1 + ((fk - 480) / 350) ** 2) + 0.5 / (1 + ((fk - 1350) / 500) ** 2) + 0.04
        out += g / k ** 0.9 * np.sin(k * ph)
    return out


def sfx_truck_horn(rng):
    n = ns(1.05)
    x = np.zeros(n)
    for t0, d in [(0.0, 0.17), (0.27, 0.62)]:  # "honk-hooonk", Bb3 + D4 (major third)
        m = ns(d)
        tone = _horn_tone(233.1, m) + 0.9 * _horn_tone(293.7, m)
        tone *= env_lin(m, [(0, 0), (0.025, 1), (d - 0.05, 0.95), (d, 0)])
        at(x, tone, t0)
    x = np.tanh(1.2 * x / np.max(np.abs(x)))
    return lp(x, 3200)


# ---- hazards --------------------------------------------------------------------

def sfx_alarm_loop(rng):
    N = ns(1.5)
    n_idx = np.arange(N)
    seg = N / 4.0
    hi_f, lo_f = 932.3, 698.5  # Bb5 / F5 alternating
    k = (n_idx // seg).astype(int)
    pos = n_idx - k * seg
    cur = np.where(k % 2 == 0, hi_f, lo_f)
    prev = np.where(k % 2 == 0, lo_f, hi_f)
    f = prev + (cur - prev) * smoothstep(pos / ns(0.012))
    f *= np.round(f.sum() / SR) / (f.sum() / SR)  # whole cycles per loop
    ph = TAU * np.cumsum(f) / SR
    tone = (np.sin(ph) + 0.15 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph) + 0.12 * np.sin(5 * ph)
            + 0.05 * np.sin(7 * ph))
    amp = 0.82 + 0.18 * np.exp(-pos / ns(0.06)) * smoothstep(pos / ns(0.004))
    return cfilt(tone * amp, hi=5000)


def sfx_fire_loop(rng):
    dur = 3.0
    N = ns(dur)
    roar = cfilt(colored(N, rng, -6), lo=70, hi=450) * (0.75 + 0.25 * slow_noise(N, rng, 2))
    flame = cfilt(white(N, rng), lo=700, hi=3200) * (0.5 + 0.5 * np.abs(slow_noise(N, rng, 10, lo=2)))
    crack = np.zeros(N)
    for _ in range(int(dur * 22)):
        p0 = rng.integers(N)
        amp = rng.exponential(0.4)
        for j in range(rng.choice([1, 1, 1, 2, 3])):
            c = crackle(rng, 1000, 4500, tau=(0.001, 0.004)) * amp * rng.uniform(0.4, 1.0)
            add_at(crack, c, p0 + j * ns(rng.uniform(0.003, 0.02)), wrap=True)
    pops = np.zeros(N)
    for _ in range(int(dur * 3)):
        add_at(pops, crackle(rng, 350, 1200, tau=(0.004, 0.012)) * rng.uniform(0.6, 1.2), rng.integers(N), wrap=True)
    x = 0.3 * unit(roar) + 0.1 * unit(flame) + 0.6 * crack + 0.5 * pops
    return cfilt(x, hi=6000, order=3)


def sfx_extinguisher_loop(rng):
    N = ns(2.0)
    spray = unit(cfilt(white(N, rng), lo=450, hi=4200, order=3)) * (0.85 + 0.15 * slow_noise(N, rng, 22, lo=6))
    rumble = unit(cfilt(white(N, rng), lo=60, hi=350))
    whistle = unit(cfilt(white(N, rng), lo=2900, hi=3300, order=4))
    return spray + 0.35 * rumble + 0.08 * whistle


def sfx_breakdown(rng):
    n = ns(1.35)
    x = modal(n, [(105, 1, 0.16), (250, 0.75, 0.11), (455, 0.5, 0.08), (820, 0.3, 0.05), (1380, 0.18, 0.03)])
    x += 0.6 * norm(lp(white(n, rng), 700)) * env_perc(n, 0.001, 0.03) + 0.7 * thump(n, 55, 1.8, tau=0.12)
    m = ns(0.42)
    gate = np.zeros(m)
    for _ in range(30):
        g0 = rng.integers(m)
        gl = ns(rng.uniform(0.003, 0.015))
        gate[g0:g0 + gl] = np.maximum(gate[g0:g0 + gl], np.hanning(gl)[:len(gate[g0:g0 + gl])] * rng.uniform(0.4, 1))
    buzz = bp(additive(120.0, [1 / k for k in range(1, 40)], m, maxf=4000), 400, 3000)
    fizz = (norm(bp(white(m, rng), 2500, 7000)) + 0.4 * norm(buzz)) * gate * env_lin(m, [(0, 1), (0.42, 0.2)])
    at(x, 0.4 * fizz, 0.04)
    m = ns(1.25)
    tt = tvec(m)
    whirr = additive(45 + 260 * np.exp(-tt / 0.38), [1 / k ** 1.3 for k in range(1, 13)], maxf=2500)
    whirr = lp(whirr * env_lin(m, [(0, 0), (0.03, 1), (1.25, 0)]) ** 1.5, 1400)
    at(x, 0.45 * norm(whirr), 0.08)
    at(x, 0.15 * metal(ns(0.3), 900, rng, decay=0.08), 0.98)
    return lp(x, 8000)


def _ratchet(rng, dur, rate):
    m = ns(dur + 0.03)
    out = np.zeros(m)
    for i in range(int(dur * rate)):
        u = rng.uniform(0.97, 1.03)
        c = modal(ns(0.03), [(3100 * u, 1, 0.006), (4650 * u, 0.6, 0.004), (2200 * u, 0.5, 0.008)])
        c += 0.5 * click(ns(0.03), rng, 6000, 0.001)
        at(out, c * rng.uniform(0.7, 1.0), i / rate)
    return out * env_lin(m, [(0, 0.6), (dur * 0.5, 1.0), (dur + 0.03, 0.7)])


def sfx_repair_loop(rng):
    N = ns(2.0)
    x = np.zeros(N)
    add_at(x, _ratchet(rng, 0.36, 20), 0.05 * SR, wrap=True)
    add_at(x, _ratchet(rng, 0.36, 21), 0.62 * SR, wrap=True)
    clank = metal(ns(0.5), 640, rng, decay=0.22) + 0.4 * thump(ns(0.5), 160, 1.4, tau=0.03)
    add_at(x, 0.9 * clank, 1.25 * SR, wrap=True)
    add_at(x, 0.35 * metal(ns(0.3), 820, rng, decay=0.1), 1.62 * SR, wrap=True)
    return cfilt(x, hi=9000)


def sfx_repair_done(rng):
    n = ns(1.1)
    x = modal(n, [(180, 1, 0.08), (420, 0.6, 0.05), (760, 0.35, 0.03)]) + thump(n, 90, 1.5, tau=0.06)
    x += 0.4 * norm(lp(white(n, rng), 1200)) * env_perc(n, 0.001, 0.01)
    at(x, 0.45 * modal(n, [(2600, 1, 0.12), (3900, 0.5, 0.08), (6100, 0.2, 0.04)]), 0.11)
    at(x, 0.5 * glock(n - ns(0.23), 1046.5, decay=0.45), 0.23)
    at(x, 0.55 * glock(n - ns(0.31), 1568.0, decay=0.5), 0.31)
    return lp(x, 10000)


def sfx_mop_loop(rng):
    dur = 2.4
    N = ns(dur)
    x = np.zeros(N)
    for i in range(3):
        m = ns(0.7)
        tt = tvec(m)
        center = 500 + 900 * tt / 0.7 if i % 2 == 0 else 1400 - 900 * tt / 0.7
        s = sweep(white(m, rng), "bp", center, q=0.9)
        slosh = 0.6 + 0.4 * norm(np.abs(lp(white(m, rng), 30)))
        s *= np.sin(np.pi * tt / 0.7) ** 1.5 * slosh
        add_at(x, norm(s), (i * 0.8 + 0.05) * SR, wrap=True)
    m = ns(0.11)
    tt = tvec(m)
    ph = phase_of(1500 * (1 + 0.05 * np.sin(TAU * 28 * tt)) * (1 + 0.15 * tt / 0.11))
    sq = (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)) * env_lin(m, [(0, 0), (0.015, 1), (0.09, 0.7), (0.11, 0)])
    add_at(x, 0.22 * sq, 1.52 * SR, wrap=True)
    for _ in range(6):
        add_at(x, bubble(loguniform(rng, 500, 1500), 0.2), rng.integers(N), wrap=True)
    x += 0.04 * unit(cfilt(white(N, rng), lo=300, hi=2500)) * (0.7 + 0.3 * slow_noise(N, rng, 3))
    return cfilt(x, lo=150, hi=5000, order=3)


def sfx_splash(rng):
    n = ns(0.9)
    x = 0.7 * norm(lp(white(n, rng), 2200)) * env_perc(n, 0.001, 0.025) + 0.5 * thump(n, 85, 1.6, tau=0.04)
    x += 0.5 * norm(bp(white(n, rng), 350, 3800)) * env_perc(n, 0.004, 0.14)
    for _ in range(45):
        ti = 0.02 + rng.exponential(0.13)
        if ti < 0.8:
            at(x, bubble(loguniform(rng, 500, 2800), rng.uniform(0.2, 0.8) * np.exp(-ti / 0.3)), ti)
    return lp(x, 8000)


def sfx_glass_break(rng):
    n = ns(0.95)
    x = 0.7 * norm(bp(white(n, rng), 1200, 6000)) * env_perc(n, 0.0005, 0.01) + 0.4 * thump(n, 160, 1.4, tau=0.02)
    for _ in range(50):
        ti = rng.exponential(0.11)
        if ti > 0.75:
            continue
        f = loguniform(rng, 2200, 6800)
        s = modal(ns(0.2), [(f, 1, rng.uniform(0.03, 0.11)), (f * rng.uniform(1.3, 1.7), 0.5, 0.03)])
        at(x, s * rng.uniform(0.15, 0.55) * np.exp(-ti / 0.25), ti)
    x += 0.12 * norm(bp(white(n, rng), 1800, 5500)) * env_perc(n, 0.002, 0.12)
    return lp(x, 8500)


# ---- UI / stings ---------------------------------------------------------------

def sfx_ui_click(rng):
    n = ns(0.07)
    t = tvec(n)
    x = np.sin(TAU * 1400 * t) * env_perc(n, 0.0005, 0.009)
    x += 0.35 * np.sin(TAU * 420 * t) * env_perc(n, 0.0005, 0.012) + 0.15 * click(n, rng, 5000, 0.0008)
    return x


def sfx_ui_hover(rng):
    n = ns(0.05)
    t = tvec(n)
    return np.sin(TAU * 2000 * t) * env_perc(n, 0.002, 0.009) + 0.3 * np.sin(TAU * 4000 * t) * env_perc(n, 0.002, 0.004)


def _blips(notes, n, harm=(1.0, 0.2, 0.0)):
    x = np.zeros(n)
    for t0, f, tau, a in notes:
        m = ns(tau * 6)
        tt = tvec(m)
        s = sum(h * np.sin(TAU * f * (k + 1) * tt) for k, h in enumerate(harm) if h)
        at(x, a * s * env_perc(m, 0.002, tau), t0)
    return x


def sfx_ui_confirm(rng):
    return _blips([(0.0, 1318.5, 0.05, 0.8), (0.065, 1760.0, 0.12, 1.0)], ns(0.35))  # E6 -> A6


def sfx_ui_back(rng):
    return lp(_blips([(0.0, 784.0, 0.04, 0.9), (0.06, 587.3, 0.08, 1.0)], ns(0.3), harm=(1.0, 0.0, 0.11)), 5000)


def sfx_ping(rng):
    n = ns(0.75)
    t = tvec(n)
    ph = phase_of(1760 * (1 - 0.04 * np.exp(-t / 0.01)))
    s = (np.sin(ph) + 0.3 * np.sin(2 * ph) * np.exp(-t / 0.08) + 0.1 * np.sin(3 * ph) * np.exp(-t / 0.04))
    s *= env_perc(n, 0.002, 0.18)
    x = s.copy()
    at(x, 0.3 * lp(s, 3000), 0.13)
    at(x, 0.12 * lp(s, 2000), 0.26)
    return x


def sfx_open_sign(rng):
    n = ns(1.4)
    x = 0.55 * small_bell(n, 1760.0, decay=0.6)
    at(x, 0.3 * small_bell(n, 2217.5, decay=0.5), 0.02)
    for i, m in enumerate((77, 81, 84, 89)):  # F5 A5 C6 F6 rising
        t0 = 0.06 + 0.085 * i
        at(x, (0.45 + 0.1 * i) * glock(n - ns(t0), mtof(m), decay=0.5), t0)
    for m in (65, 69, 72, 76, 79):  # Fmaj9 bloom
        at(x, 0.22 * inst_epiano(mtof(m), 0.75, 0.6, rng), 0.42 + 0.006 * rng.random())
    for t0, m in ((0.45, 96), (0.52, 101)):
        at(x, 0.15 * glock(n - ns(t0), mtof(m), decay=0.3), t0)
    return lp(x, 10000)


def sfx_day_end(rng):
    n = ns(1.7)
    x = np.zeros(n)
    for i, m in enumerate((84, 81, 77, 72)):  # C6 A5 F5 C5 descending
        at(x, inst_vibes(mtof(m), 0.6, 0.7, rng), 0.17 * i)
    for m in (65, 69, 72, 76):  # Fmaj7 to settle
        at(x, 0.6 * inst_vibes(mtof(m), 0.9, 0.5, rng), 0.7)
    t = tvec(n)
    x *= 1.0 - 0.22 * (0.5 + 0.5 * np.sin(TAU * 5.0 * t))
    return lp(x, 6000)


def sfx_level_up(rng):
    n = ns(1.15)
    x = np.zeros(n)
    for t0, m, d in [(0.0, 72, 0.09), (0.09, 77, 0.09), (0.18, 81, 0.09), (0.27, 84, 0.6)]:
        at(x, inst_brass(mtof(m), d, 0.9, rng), t0)
    for m in (65, 69, 72):
        at(x, 0.5 * inst_brass(mtof(m), 0.6, 0.7, rng), 0.27)
    for i, m in enumerate((89, 93, 96, 101)):
        t0 = 0.3 + 0.04 * i
        at(x, 0.12 * glock(n - ns(t0), mtof(m), decay=0.3), t0)
    return lp(x, 9000)


def sfx_error(rng):
    n = ns(0.35)
    x = np.zeros(n)
    for t0, f, d in [(0.0, 311.1, 0.07), (0.09, 233.1, 0.16)]:  # Eb4 -> Bb3 "bonk-bonk"
        m = ns(d + 0.1)
        tt = tvec(m)
        ph = phase_of(f * (1 - 0.06 * tt / (d + 0.1)))
        s = np.sin(ph) + 0.12 * np.sin(3 * ph) + 0.25 * np.sin(2 * ph) * np.exp(-tt / 0.02)
        at(x, s * env_perc(m, 0.003, d * 0.6), t0)
    x += 0.25 * norm(lp(white(n, rng), 400)) * env_perc(n, 0.001, 0.015)
    return lp(x, 4000)


def sfx_spoil(rng):
    n = ns(0.55)
    m = ns(0.38)
    tt = tvec(m)
    ph = phase_of((120 + 200 * np.exp(-tt / 0.12)) * (1 + 0.12 * np.sin(TAU * 16 * tt)))
    s = np.sin(ph) + 0.6 * np.sin(2 * ph) * np.exp(-tt / 0.08) + 0.3 * np.sin(3 * ph) * np.exp(-tt / 0.05)
    s *= env_lin(m, [(0, 0), (0.012, 1), (0.25, 0.6), (0.38, 0)])
    x = pad(s, n)
    for _ in range(6):
        at(x, bubble(loguniform(rng, 150, 400), 0.4), rng.uniform(0.02, 0.3))
    x += 0.25 * norm(bp(white(n, rng), 300, 1400)) * env_perc(n, 0.003, 0.05)
    return lp(x, 3500)


# ---- building / machines --------------------------------------------------------

def sfx_build_place(rng):
    n = ns(0.5)
    x = thump(n, 70, 1.9, tau=0.09, sweep_tau=0.014) + 0.8 * wood(n, 175, rng, decay=0.08, bright=0.7)
    x += 0.4 * norm(lp(white(n, rng), 1500)) * env_perc(n, 0.001, 0.012)
    at(x, 0.25 * wood(n, 320, rng, decay=0.03), 0.055)
    return lp(x, 4000)


def sfx_build_lift(rng):
    n = ns(0.5)
    x = np.zeros(n)
    m = ns(0.22)
    tt = tvec(m)
    rate = 95 + 70 * tt / 0.22 + 10 * np.sin(TAU * 13 * tt)
    cyc = np.floor(np.cumsum(rate) / SR)
    exc = (np.diff(cyc, prepend=0) > 0).astype(float) * rng.uniform(0.5, 1.0, m)
    creak = biquad(exc, "bp", 520, 6) + 0.7 * biquad(exc, "bp", 1150, 7) + 0.4 * biquad(exc, "bp", 2100, 8)
    creak *= env_lin(m, [(0, 0), (0.03, 1), (0.18, 0.8), (0.22, 0)])
    at(x, norm(creak), 0.0)
    m = ns(0.4)
    tt = tvec(m)
    w = sweep(lp(white(m, rng), 3000), "bp", 350 * (1 + 5 * (tt / 0.4) ** 1.5), q=1.0)
    w *= env_lin(m, [(0, 0), (0.22, 1), (0.4, 0)])
    at(x, 0.5 * norm(w), 0.05)
    return lp(x, 7000)


def sfx_construct(rng):
    n = ns(1.25)
    x = np.zeros(n)
    for i, (t0, a) in enumerate([(0.0, 1.0), (0.17, 0.85), (0.34, 0.95), (0.52, 0.8)]):
        m = ns(0.2)
        h = wood(m, 240 * (1 + 0.04 * i), rng, decay=0.04, bright=1.2) + 0.5 * thump(m, 120, 1.5, tau=0.03)
        h += 0.35 * modal(m, [(2650, 1, 0.025), (4100, 0.5, 0.015)])
        at(x, a * h, t0)
    m = ns(0.38)
    tt = tvec(m)
    teeth = (0.5 + 0.5 * np.cos(TAU * 42 * tt)) ** 2
    z = sweep(lp(white(m, rng), 5000), "bp", 1600 + 1800 * tt / 0.38, q=1.4)
    z *= (0.4 + 0.6 * teeth) * env_lin(m, [(0, 0), (0.04, 1), (0.3, 0.9), (0.38, 0)])
    at(x, 0.6 * norm(z), 0.74)
    return lp(x, 6500)


def sfx_trash(rng):
    n = ns(0.75)

    def flap(m):
        y = modal(m, [(240, 1, 0.05), (560, 0.6, 0.035), (1100, 0.4, 0.02), (1850, 0.2, 0.012)])
        return y + 0.5 * thump(m, 110, 1.4, tau=0.03) + 0.2 * click(m, rng, 4000, 0.002)

    x = flap(n)
    at(x, 0.45 * flap(ns(0.3)), 0.13)
    at(x, 0.2 * flap(ns(0.3)), 0.22)
    at(x, 0.45 * norm(grains(n, rng, 70, 0.4, 1000, 4500, amp_tau=0.25)), 0.02)
    return lp(x, 6000)


def sfx_conveyor_loop(rng):
    dur = 2.0
    N = ns(dur)
    t = tvec(N)
    ph = TAU * 100.0 * t
    hum = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)
    whine = np.sin(TAU * 880.0 * t)
    rumble = unit(cfilt(white(N, rng), lo=60, hi=500)) * (0.85 + 0.15 * slow_noise(N, rng, 6))
    clicks = np.zeros(N)
    for k in range(32):  # 16 roller clacks per second, whole pattern per loop
        u = rng.uniform(0.95, 1.05)
        m = ns(0.04)
        c = modal(m, [(1900 * u, 1, 0.006), (2900 * u, 0.5, 0.004)]) + 0.6 * modal(m, [(230, 1, 0.012)])
        a = (1.0, 0.7, 0.85, 0.6)[k % 4] * rng.uniform(0.85, 1.0)
        add_at(clicks, a * c, (k + 0.5) * N / 32 + rng.normal(0, 30), wrap=True)
    for _ in range(20):
        add_at(clicks, 0.25 * modal(ns(0.02), [(loguniform(rng, 1500, 4000), 1, 0.003)]), rng.integers(N), wrap=True)
    x = 0.15 * hum + 0.02 * whine + 0.35 * rumble + 0.6 * clicks
    return cfilt(x, lo=40, hi=7000)


def sfx_grabber(rng):
    n = ns(0.55)
    x = np.zeros(n)
    m = ns(0.24)
    tt = tvec(m)
    pssht = sweep(lp(white(m, rng), 6000), "bp", 4200 - 2200 * tt / 0.24, q=0.8)
    pssht *= env_lin(m, [(0, 0), (0.015, 1), (0.08, 0.7), (0.24, 0)])
    at(x, 0.6 * norm(pssht), 0.0)
    m = ns(0.2)
    clack = modal(m, [(1150, 1, 0.022), (2350, 0.6, 0.014), (3650, 0.3, 0.008)])
    clack += 0.5 * thump(m, 170, 1.4, tau=0.02) + 0.3 * click(m, rng, 5000, 0.0015)
    at(x, clack, 0.2)
    return lp(x, 8000)


def sfx_timer_ring(rng):
    n = ns(1.0)
    x = np.zeros(n)
    rate, dur = 24.0, 0.7
    for i in range(int(dur * rate)):
        t0 = max(0.0, i / rate + rng.normal(0, 0.0015))
        m = n - ns(t0)
        b = modal(m, [(2350, 1, 0.35), (2358, 0.5, 0.3), (5300, 0.25, 0.08), (6600, 0.1, 0.04)])
        b += 0.15 * click(m, rng, 3000, 0.002)
        at(x, rng.uniform(0.75, 1.0) * b, t0)
    return lp(x, 9000)


def sfx_whoosh(rng):
    n = ns(0.4)
    t = tvec(n)
    fc = 300 + 1500 * np.sin(np.pi * np.clip(t / 0.32, 0, 1)) ** 2
    env = env_lin(n, [(0, 0), (0.14, 1), (0.32, 0.15), (0.4, 0)]) ** 1.3
    w = norm(sweep(lp(white(n, rng), 3500), "bp", fc, q=1.1)) * env
    return w + 0.4 * norm(lp(white(n, rng), 250)) * env


# =============================================================================
# Music: instruments
# =============================================================================

def inst_epiano(f, dur, vel, rng):
    """Tine electric piano (1:1 FM with decaying index + bell partial + tine)."""
    n = ns(dur + 0.25)
    t = tvec(n)
    decay = float(np.clip(2.2 * (220.0 / f) ** 0.5, 0.5, 3.0))
    amp = smoothstep(t / 0.002) * np.exp(-t / decay)
    off = t > dur
    amp[off] *= np.exp(-(t[off] - dur) / 0.06)
    idx = (0.3 + 1.6 * vel) * np.exp(-t / 0.3) + 0.15
    ph = TAU * f * t
    x = np.sin(ph + idx * np.sin(ph))
    x += 0.25 * vel * np.sin(2 * ph) * np.exp(-t / 0.5)
    if f * 6.9 < 14000:
        x += 0.06 * vel * np.sin(6.9 * ph) * np.exp(-t / 0.012)
    return vel * amp * x


def inst_vibes(f, dur, vel, rng):
    """Vibraphone bar (1 : 4 : 10 partials) with soft mallet."""
    n = ns(dur + 0.35)
    t = tvec(n)
    d1 = float(np.clip(3.0 * (440.0 / f) ** 0.4, 0.8, 4.0))
    x = np.sin(TAU * f * t) * np.exp(-t / d1)
    if 4 * f < 15000:
        x += 0.22 * vel * np.sin(TAU * 4 * f * t) * np.exp(-t / (d1 * 0.12))
    if 10 * f < 9000:
        x += 0.05 * vel * np.sin(TAU * 10 * f * t) * np.exp(-t / 0.03)
    x *= smoothstep(t / 0.0015)
    x += 0.05 * vel * norm(lp(white(n, rng), 2500)) * np.exp(-t / 0.004)
    off = t > dur
    x[off] *= np.exp(-(t[off] - dur) / 0.1)
    return vel * x


def inst_pluck(f, dur, vel, rng, bright=1.0, tau0=1.0, pos=0.2, maxf=5000.0, noise=0.08):
    """Plucked string (additive; higher harmonics decay faster)."""
    n = ns(dur + 0.08)
    t = tvec(n)
    x = np.zeros(n)
    for k in range(1, int(min(40, maxf / f)) + 1):
        a = abs(math.sin(math.pi * k * pos)) / k ** 1.15
        tau = tau0 / (1 + 0.35 * (k - 1) ** 1.5 / bright)
        fk = f * k * math.sqrt(1 + 0.0002 * k * k)
        x += a * np.exp(-t / tau) * np.sin(TAU * fk * t)
    x *= smoothstep(t / 0.004)
    x += noise * bright * norm(lp(white(n, rng), 900 + 1500 * bright)) * np.exp(-t / 0.008)
    off = t > dur
    x[off] *= np.exp(-(t[off] - dur) / 0.035)
    return vel * x


def inst_bass(f, dur, vel, rng):  # plucky upright-ish (groove)
    return inst_pluck(f, dur, vel, rng, bright=1.0, tau0=0.9, pos=0.22, maxf=4000)


def inst_softbass(f, dur, vel, rng):  # round and warm (base / closing)
    return inst_pluck(f, dur, vel, rng, bright=0.4, tau0=1.3, pos=0.3, maxf=2000, noise=0.04)


def inst_comp(f, dur, vel, rng):  # short muted-guitar style chord stab
    return inst_pluck(f, dur, vel, rng, bright=1.6, tau0=0.16, pos=0.17, maxf=6000, noise=0.12)


def inst_brass(f, dur, vel, rng):
    """Brassy section stab: additive saw with a fast 'blat' brightness envelope."""
    n = ns(dur + 0.1)
    t = tvec(n)
    env = smoothstep(t / 0.03) * (0.8 + 0.2 * np.exp(-t / 0.1))
    off = t > dur
    env[off] *= np.exp(-(t[off] - dur) / 0.045)
    bright = (1 - np.exp(-t / 0.025)) * (0.6 + 0.4 * np.exp(-t / 0.12))
    cutoff = f * (1.0 + (2.0 + 4.5 * vel) * bright)
    out = np.zeros(n)
    for det, g in ((1.0, 1.0), (1.0035, 0.7), (0.9968, 0.6)):
        ph = phase_of(f * det * (1 - 0.025 * np.exp(-t / 0.03)))
        for k in range(1, int(7000 / f) + 1):
            out += g / k / np.sqrt(1 + (k * f / cutoff) ** 4) * np.sin(k * ph)
    return vel * np.tanh(0.6 * out * env)


# ---- drums ------------------------------------------------------------------

def drum_kick(vel, rng):
    n = ns(0.45)
    t = tvec(n)
    x = np.sin(phase_of(56 + 70 * np.exp(-t / 0.03))) * np.exp(-t / 0.18) * smoothstep(t / 0.001)
    x += 0.25 * norm(lp(white(n, rng), 2500)) * np.exp(-t / 0.004)
    return vel * np.tanh(1.3 * x) / np.tanh(1.3)


def drum_brush(vel, rng):
    n = ns(0.35)
    t = tvec(n)
    nz = norm(lp(hp(white(n, rng), 700), 4800))
    x = nz * smoothstep(t / 0.008) * np.exp(-t / 0.085) + 0.3 * np.sin(TAU * 185 * t) * np.exp(-t / 0.05)
    return vel * x


def drum_snare_lofi(vel, rng):
    n = ns(0.3)
    t = tvec(n)
    x = 0.8 * norm(bp(white(n, rng), 900, 5000)) * smoothstep(t / 0.002) * np.exp(-t / 0.07)
    x += 0.5 * np.sin(TAU * 200 * t) * np.exp(-t / 0.04) + 0.3 * modal(n, [(1650, 1, 0.012), (3200, 0.4, 0.006)])
    return vel * x


def drum_hat(vel, rng, decay=0.04):
    n = ns(decay * 6 + 0.01)
    t = tvec(n)
    nz = norm(lp(hp(white(n, rng), 5000, 2), 9000, 2))
    ring = 0.1 * (np.sin(TAU * 6100 * t) + np.sin(TAU * 7900 * t + 1.0))
    return vel * (nz + ring) * smoothstep(t / 0.0006) * np.exp(-t / decay)


def drum_shaker(vel, rng):
    n = ns(0.12)
    t = tvec(n)
    return vel * norm(bp(white(n, rng), 3000, 7500)) * smoothstep(t / 0.012) * np.exp(-t / 0.03)


def drum_tom(f, vel, rng):
    n = ns(0.5)
    t = tvec(n)
    x = np.sin(phase_of(f * (1 + 0.4 * np.exp(-t / 0.03)))) * np.exp(-t / 0.2) * smoothstep(t / 0.001)
    x += 0.2 * norm(lp(white(n, rng), 1500)) * np.exp(-t / 0.02)
    return vel * x


# =============================================================================
# Music: sequencing, mixing, reverb
# =============================================================================

NOTE_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_num(name):
    semi = NOTE_BASE[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        semi += 1 if name[i] == "#" else -1
        i += 1
    return semi + 12 * (int(name[i:]) + 1)


def parse_melody(bars, vel=0.8):
    """One string per 4/4 bar, tokens 'Name:beats', 'r' = rest."""
    events = []
    for bi, bar in enumerate(bars):
        beat = 0.0
        for tok in bar.split():
            name, d = tok.split(":")
            d = float(d)
            if name != "r":
                accent = (1.0 if abs(beat % 1) < 1e-9 else 0.88) * (1.06 if d >= 1 else 1.0)
                events.append((bi * 4 + beat, d, note_num(name), min(1.0, vel * accent)))
            beat += d
        assert abs(beat - 4) < 1e-6, f"melody bar {bi + 1} has {beat} beats"
    return events


def make_ir(seconds, t60, seed, predelay=0.015, bright_hz=7000.0, dark_hz=2000.0):
    """Stereo reverb impulse response: decaying noise that darkens over time,
    a few early reflections, unit energy per channel."""
    rng = np.random.default_rng(seed)
    n = ns(seconds)
    t = tvec(n)
    pd = ns(predelay)
    out = np.zeros((2, n + pd))
    for ch in range(2):
        nz = rng.standard_normal(n)
        w = np.exp(-t / (t60 * 0.25))
        tail = (w * lp(nz, bright_hz) + (1 - w) * lp(nz, dark_hz)) * 10 ** (-3 * t / t60)
        tail *= smoothstep(t / 0.02)
        for _ in range(8):
            k = ns(rng.uniform(0.004, 0.06))
            tail[k] += rng.choice([-1, 1]) * rng.uniform(0.5, 1.5) * np.std(tail[:ns(0.1)]) * 6
        tail *= smoothstep(t / 0.001)
        out[ch, pd:] = tail
    out /= np.sqrt(np.sum(out ** 2, axis=1, keepdims=True))
    return out


def active_rms(x, block=4096):
    """RMS over the 'active' (non-silent) parts of a track."""
    nb = len(x) // block
    if nb == 0:
        return float(np.sqrt(np.mean(x ** 2)) + 1e-12)
    r = np.sqrt(np.mean(x[:nb * block].reshape(nb, block) ** 2, axis=1))
    act = r[r > r.max() * dbg(-30)]
    return float(np.sqrt(np.mean(act ** 2)) + 1e-12)


class Song:
    """Tempo grid with swing, humanization and circular (loopable) tracks."""

    def __init__(self, bpm, bars, swing=0.6, seed=1, tail=6.0):
        self.bpm, self.bars, self.swing = bpm, bars, swing
        self.spb = SR * 60.0 / bpm
        self.beats = bars * 4
        self.N = int(round(self.beats * self.spb))
        self.tail = ns(tail)
        self.rng = np.random.default_rng(seed)

    def sample(self, beat, jitter_ms=0.0):
        """Beat position -> sample position, with swung 8ths (and 16ths)."""
        b = math.floor(beat + 1e-9)
        fr = beat - b
        s = self.swing
        fr2 = fr / 0.5 * s if fr < 0.5 else s + (fr - 0.5) / 0.5 * (1 - s)
        pos = (b + fr2) * self.spb
        if jitter_ms:
            j = float(np.clip(self.rng.normal(0, jitter_ms), -2.5 * jitter_ms, 2.5 * jitter_ms))
            if abs(beat % self.beats) < 1e-9:
                j = abs(j)  # keep loop-start onsets inside the file (no transient across the seam)
            pos += j * SR / 1000
        return pos

    def secs(self, beat, dur):
        return (self.sample(beat + dur) - self.sample(beat)) / SR

    def track(self):
        return np.zeros(self.N + self.tail)

    def place(self, trk, x, pos):
        add_at(trk, x[:self.tail + self.N - 1], int(round(pos)) % self.N)

    def fold(self, trk):
        """Wrap everything that rings past the loop end back onto the start."""
        y = trk[:self.N].copy()
        r = trk[self.N:]
        y[:len(r)] += r
        return y

    def notes(self, inst, events, jitter=5.0, vel_jit=0.06, strum=0.008, gate=1.0):
        """events: (beat, dur_beats, midi or [midis], velocity).  Returns a folded track."""
        trk = self.track()
        for beat, dur, mids, vel in events:
            mids = [mids] if np.ndim(mids) == 0 else list(mids)
            p0 = self.sample(beat, jitter)
            d = self.secs(beat, dur) * gate
            for j, m in enumerate(sorted(mids)):
                v = float(np.clip(vel * (1 + self.rng.normal(0, vel_jit)), 0.05, 1.0))
                off = j * self.rng.uniform(0, strum) * SR if len(mids) > 1 else 0
                self.place(trk, inst(mtof(m), d, v, self.rng), p0 + off)
        return self.fold(trk)

    def hits(self, fn, events, jitter=3.0, vel_jit=0.08):
        """Drum hits: events = (beat, velocity)."""
        trk = self.track()
        for beat, vel in events:
            v = float(np.clip(vel * (1 + self.rng.normal(0, vel_jit)), 0.02, 1.0))
            self.place(trk, fn(v, self.rng), self.sample(beat, jitter))
        return self.fold(trk)

    def lfo(self, cycles_per_beat, phase=0.0):
        """Tempo-synced LFO with a whole number of cycles per loop."""
        k = round(cycles_per_beat * self.beats)
        return np.sin(TAU * k * np.arange(self.N) / self.N + phase)

    def whistle(self, events, jitter=5.0):
        """Monophonic whistle/flute lead with legato glides, tonguing,
        delayed vibrato and breath noise, rendered as one continuous line."""
        T = self.N + self.tail
        ev = sorted((self.sample(b, jitter), self.sample(b + d) - 0.012 * SR, m, v) for b, d, m, v in events)
        pitch = np.zeros(T)
        amp = np.zeros(T)
        vibd = np.zeros(T)
        scoop = np.zeros(T)
        gap = 0.12 * SR
        for i, (s, e, m, v) in enumerate(ev):
            s = int(s)
            leg_prev = i > 0 and s - ev[i - 1][1] < gap
            nxt = int(ev[i + 1][0]) if i + 1 < len(ev) else None
            leg_next = nxt is not None and nxt - e < gap
            end = nxt if leg_next else min(T, int(e) + ns(0.07))
            L = end - s
            t = tvec(L)
            a = v * (0.9 + 0.1 * np.exp(-t / 0.25))
            if leg_prev:
                a *= 1 - 0.55 * np.exp(-t / 0.02)  # tongued re-articulation
            else:
                a *= smoothstep(t / 0.03)
                scoop[s:end] = -0.45 * np.exp(-t / 0.04)
            if not leg_next:
                k = int(e) - s
                if 0 < k < L:
                    a[k:] *= np.linspace(1, 0, L - k)
            amp[s:end] = a
            pitch[s:end] = m
            vibd[s:end] = 0.22 * smoothstep((t - 0.15) / 0.3)
            if nxt is not None and not leg_next:
                pitch[end:nxt] = ev[i + 1][2]  # pre-load next pitch during rests
        first = int(ev[0][0])
        pitch[:first] = ev[0][2]
        last_end = np.nonzero(amp)[0][-1] + 1
        pitch[last_end:] = ev[-1][2]
        a = math.exp(-1.0 / (0.018 * SR))  # short portamento between legato notes
        pitch = sps.lfilter([1 - a], [1, -a], pitch, zi=[a * pitch[0]])[0]
        vib = vibd * np.sin(TAU * 5.4 * np.arange(T) / SR)
        f = mtof(pitch + scoop + vib)
        ph = phase_of(f)
        tone = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.035 * np.sin(3 * ph)
        breath = unit(bp(white(T, self.rng), 1500, 5000))
        chiff = np.zeros(T)  # breathy 'tu' at each note start
        for s, e, m, v in ev:
            k = ns(0.04)
            add_at(chiff, v * np.exp(-tvec(k) / 0.012), int(s))
        x = amp * tone + (0.03 * np.sqrt(np.abs(amp)) + 0.08 * chiff) * breath
        return self.fold(x)


class Mix:
    """Stereo mix bus with a shared (circular) reverb send."""

    def __init__(self, song):
        self.song = song
        self.dry = np.zeros((2, song.N))
        self.send = np.zeros(song.N)

    def add(self, mono, level_db, pan=0.0, send=0.0, autopan=None):
        x = mono * (dbg(level_db) / active_rms(mono))
        p = pan + (autopan if autopan is not None else 0.0)
        th = (np.clip(p, -1, 1) + 1) * np.pi / 4
        self.dry[0] += x * np.cos(th)
        self.dry[1] += x * np.sin(th)
        self.send += x * send
        return x

    def add_stereo(self, st, gain=1.0, send=0.0):
        self.dry += st * gain
        self.send += st.mean(axis=0) * gain * send

    def render(self, ir, send_lo=180.0):
        s = cfilt(self.send, lo=send_lo, order=2)
        wet = np.array([cconv(s, ir[0]), cconv(s, ir[1])])
        return self.dry + wet


def pingpong(x, delay, fb=0.35, taps=5):
    """Circular stereo ping-pong delay (seamless on loops)."""
    out = np.zeros((2, len(x)))
    for k in range(1, taps + 1):
        out[(k + 1) % 2] += np.roll(x, k * delay) * fb ** k
    return cfilt(out, lo=300, hi=4500)


def chord_segments(prog):
    segs = []
    for bar, chords in enumerate(prog):
        for j, (b, voicing, root) in enumerate(chords):
            end = chords[j + 1][0] if j + 1 < len(chords) else 4
            segs.append(dict(bar=bar, start=bar * 4 + b, length=end - b, voicing=voicing, root=root))
    return segs


def chord_at(segs, beat):
    total = segs[-1]["start"] + segs[-1]["length"]
    beat %= total
    for s in segs:
        if s["start"] <= beat < s["start"] + s["length"]:
            return s
    return segs[0]


def fifth_below_or_above(root, ceiling=48):
    return root + 7 if root + 7 <= ceiling else root - 5


# =============================================================================
# Music: compositions
# =============================================================================

# One entry per bar: [(beat_in_bar, voicing (MIDI), bass root (MIDI)), ...]
MAIN_PROG = [
    [(0, [57, 60, 64, 67], 41)],                             # Fmaj9
    [(0, [57, 60, 64, 65], 38)],                             # Dm9
    [(0, [58, 62, 65, 69], 43)],                             # Gm9
    [(0, [58, 62, 64, 69], 36)],                             # C13
    [(0, [57, 60, 64, 67], 41)],                             # Fmaj9
    [(0, [55, 60, 64, 69], 45)],                             # Am7
    [(0, [57, 60, 62, 65], 46)],                             # Bbmaj9
    [(0, [58, 62, 64, 67], 36)],                             # C9
    [(0, [57, 60, 64, 65], 38)],                             # Dm9
    [(0, [53, 59, 64, 69], 43)],                             # G13
    [(0, [53, 58, 62, 69], 43)],                             # Gm9
    [(0, [52, 58, 62, 69], 36)],                             # C13
    [(0, [52, 57, 60, 67], 41)],                             # Fmaj9
    [(0, [54, 60, 64, 69], 38)],                             # D9
    [(0, [53, 58, 62, 69], 43), (2, [52, 58, 62, 69], 36)],  # Gm9  C13
    [(0, [52, 57, 60, 67], 41), (2, [55, 58, 62, 65], 36)],  # Fmaj9  C9sus4 (turnaround)
]

MAIN_WALK = [  # groove walking bass, quarter notes (beat 1 = root, beat 3 = chord tone)
    [41, 45, 48, 49], [50, 48, 45, 44], [43, 46, 50, 47], [48, 46, 43, 40],
    [41, 45, 48, 46], [45, 48, 52, 47], [46, 45, 41, 47], [48, 43, 46, 49],
    [50, 48, 45, 42], [43, 47, 50, 45], [43, 45, 46, 47], [48, 46, 43, 40],
    [41, 45, 48, 49], [50, 45, 42, 44], [43, 46, 48, 40], [41, 45, 48, 40],
]

MAIN_VIBES = [  # base-layer vibraphone answers: (bar 1-based, beat, dur, midi)
    (2, 2, .5, 69), (2, 2.5, .5, 72), (2, 3, 1, 74),
    (4, 2, .5, 70), (4, 2.5, .5, 69), (4, 3, 1, 67),
    (6, 2, .5, 72), (6, 2.5, .5, 76), (6, 3, 1, 79),
    (8, 1.5, .5, 76), (8, 2, .5, 74), (8, 2.5, 1.5, 70),
    (10, 2, .5, 71), (10, 2.5, .5, 74), (10, 3, 1, 77),
    (12, 2, .5, 76), (12, 2.5, .5, 72), (12, 3, 1, 70),
    (14, 2, .5, 66), (14, 2.5, .5, 69), (14, 3, 1, 72),
    (16, 2, .5, 72), (16, 2.5, .5, 70), (16, 3, 1, 67),
]

MAIN_MELODY = [  # rush-hour whistle lead
    "r:.5 C5:.5 F5:.5 A5:.5 C6:1 A5:.5 G5:.5",
    "A5:1 G5:.5 F5:.5 E5:.5 F5:1 r:.5",
    "r:.5 D5:.5 G5:.5 Bb5:.5 D6:1 Bb5:.5 A5:.5",
    "G5:1 E5:.5 C5:.5 Bb4:.5 C5:1 r:.5",
    "r:.5 C5:.5 F5:.5 A5:.5 C6:1 A5:.5 G5:.5",
    "E6:1.5 D6:.5 C6:.5 A5:1 r:.5",
    "r:.5 D6:.5 C6:.5 A5:.5 F5:1 G5:.5 A5:.5",
    "Bb5:1 A5:.5 G5:1.5 r:.5 E5:.5",
    "F5:.5 A5:.5 C6:.5 D6:1 C6:.5 A5:1",
    "B5:1.5 A5:.5 G5:.5 F5:.5 D5:1",
    "r:.5 Bb5:.5 A5:.5 G5:.5 F5:1 D5:1",
    "E5:.5 G5:.5 Bb5:.5 C6:1.5 r:1",
    "A5:.5 C6:.5 A5:.5 F5:1 G5:.5 A5:1",
    "F#5:1 A5:.5 C6:1 D6:.5 C6:1",
    "Bb5:1 A5:.5 G5:.5 E5:1 G5:.5 Bb5:.5",
    "A5:1.5 G5:.5 F5:1 r:1",
]

CLOSE_PROG = [
    [(0, [57, 60, 64, 67], 41)],                             # Fmaj9
    [(0, [55, 60, 62, 64], 45)],                             # Am11
    [(0, [57, 60, 62, 65], 46)],                             # Bbmaj9
    [(0, [56, 60, 61, 65], 46)],                             # Bbm9 (minor iv)
    [(0, [55, 60, 62, 64], 45)],                             # Am11
    [(0, [54, 60, 64, 69], 38)],                             # D9
    [(0, [53, 58, 62, 69], 43)],                             # Gm9
    [(0, [52, 58, 62, 69], 36)],                             # C13
    [(0, [57, 60, 64, 67], 41)],                             # Fmaj9
    [(0, [55, 60, 62, 64], 45)],                             # Am11
    [(0, [57, 60, 62, 65], 46)],                             # Bbmaj9
    [(0, [56, 60, 61, 65], 46)],                             # Bbm9
    [(0, [55, 60, 62, 64], 45)],                             # Am11
    [(0, [54, 60, 64, 69], 38)],                             # D9
    [(0, [53, 58, 62, 69], 43)],                             # Gm9
    [(0, [55, 58, 62, 65], 36), (2, [52, 58, 62, 69], 36)],  # C9sus4  C13
]

CLOSE_MELODY = [
    "r:1 E5:.5 F5:.5 A5:1.5 G5:.5",
    "E5:2.5 r:.5 C5:.5 D5:.5",
    "F5:1 D5:.5 C5:.5 A4:2",
    "r:1 Db5:.5 F5:.5 Ab5:1 F5:1",
    "E5:2 C5:.5 D5:.5 E5:1",
    "F#5:1.5 E5:.5 D5:1 C5:1",
    "Bb4:.5 D5:.5 F5:.5 A5:2.5",
    "G5:1 E5:1 r:2",
    "r:.5 A5:.5 C6:.5 A5:.5 G5:1 E5:1",
    "E5:1.5 G5:.5 E5:1 C5:1",
    "D5:1 F5:.5 A5:1.5 G5:.5 F5:.5",
    "Db5:1 F5:1 Eb5:.5 Ab5:1.5",
    "A5:1.5 G5:.5 E5:2",
    "F#5:1 A5:.5 C6:1 A5:.5 F#5:1",
    "G5:1 F5:.5 D5:1.5 r:1",
    "r:1 D5:.5 F5:.5 G5:1 E5:1",
]

MENU_PROG = [
    [(0, [57, 60, 64, 67], 41)],                             # Fmaj9
    [(0, [58, 62, 65, 69], 43), (2, [58, 62, 64, 69], 36)],  # Gm9  C13
    [(0, [57, 60, 64, 67], 41)],                             # Fmaj9
    [(0, [58, 62, 63, 67], 36), (2, [57, 62, 63, 67], 41)],  # Cm9  F13
    [(0, [57, 60, 62, 65], 46)],                             # Bbmaj9
    [(0, [56, 60, 61, 65], 46), (2, [55, 58, 61, 65], 39)],  # Bbm9  Eb9
    [(0, [55, 60, 64, 67], 45)],                             # Am7
    [(0, [54, 60, 64, 69], 38)],                             # D9
    [(0, [53, 58, 62, 69], 43)],                             # Gm9
    [(0, [52, 58, 62, 69], 36)],                             # C13
    [(0, [55, 60, 64, 67], 45)],                             # Am7
    [(0, [54, 60, 64, 69], 38)],                             # D9
    [(0, [53, 58, 62, 69], 43)],                             # Gm9
    [(0, [52, 58, 61, 67], 36)],                             # C7b9
    [(0, [52, 57, 60, 67], 41), (2, [53, 57, 60, 64], 38)],  # Fmaj9  Dm9
    [(0, [53, 58, 62, 65], 43), (2, [52, 58, 62, 67], 36)],  # Gm7  C9
]

MENU_MELODY = [
    "C5:.5 F5:.5 A5:.5 C6:1.5 A5:.5 F5:.5",
    "G5:1 Bb5:1 Bb5:.5 A5:.5 G5:1",
    "A5:1.5 G5:.5 F5:.5 E5:.5 F5:1",
    "Eb5:.5 G5:.5 Bb5:1 A5:.5 C6:.5 Eb6:1",
    "D6:2.5 C6:.5 A5:1",
    "Db6:1 C6:1 Bb5:1 G5:1",
    "A5:1.5 G5:.5 E5:1 C5:1",
    "D5:.5 F#5:.5 A5:.5 C6:1.5 r:1",
    "Bb5:1 A5:.5 Bb5:.5 D6:1 Bb5:1",
    "G5:1.5 E5:.5 C5:1 D5:.5 E5:.5",
    "G5:1 E5:.5 G5:.5 C6:2",
    "Bb5:.5 A5:.5 F#5:.5 A5:.5 C6:1.5 r:.5",
    "Bb5:1.5 A5:.5 G5:1 F5:1",
    "E5:.5 G5:.5 Bb5:.5 Db6:1 C6:.5 Bb5:1",
    "A5:1.5 C6:.5 A5:1 F5:1",
    "G5:1 A5:.5 Bb5:.5 C6:1 r:1",
]


def brush_swirl(song, rng):
    """Continuous brush circles: band-passed noise swelling every two beats."""
    sw = cfilt(white(song.N, rng), lo=1500, hi=5500)
    ph = (np.arange(song.N) / song.spb) % 2.0 / 2.0
    return sw * (0.25 + 0.75 * np.sin(np.pi * ph) ** 2)


def render_main_stems():
    """The three layered service stems (112 BPM, F major, 16 bars)."""
    song = Song(112, 16, swing=0.6, seed=112)
    segs = chord_segments(MAIN_PROG)
    ir = make_ir(2.4, 1.7, seed=11)
    beats = song.beats

    # ---------------- stem_base: e-piano + vibes answers + soft bass + shaker
    base = Mix(song)
    ep = []
    for s in segs:
        v, st, L = s["voicing"], s["start"], s["length"]
        if L == 4 and s["bar"] % 2 == 0:
            ep += [(st, 2.35, v, 0.62), (st + 2.5, 1.4, v[1:], 0.42)]
        elif L == 4:
            ep += [(st, 1.35, v, 0.58), (st + 1.5, 2.4, v[1:], 0.45)]
        else:
            ep += [(st, L - 0.1, v, 0.58)]
    epiano = cfilt(song.notes(inst_epiano, ep, jitter=6, strum=0.01), hi=8000)
    base.add(epiano, -19, pan=0.0, send=0.22, autopan=0.3 * song.lfo(0.5))
    vib_ev = [((b - 1) * 4 + bt, d * 1.6, m, 0.6) for b, bt, d, m in MAIN_VIBES]
    vibes = song.notes(inst_vibes, vib_ev, jitter=5) * (1 - 0.25 * (0.5 + 0.5 * song.lfo(3)))
    base.add(vibes, -26, pan=-0.35, send=0.3)
    bass_ev = []
    for s in segs:
        r, st, L = s["root"], s["start"], s["length"]
        if L == 4:
            bass_ev += [(st, 1.7, r, 0.8), (st + 2, 1.6, fifth_below_or_above(r), 0.65)]
        else:
            bass_ev += [(st, L - 0.25, r, 0.75)]
    base.add(song.notes(inst_softbass, bass_ev, jitter=4), -20, pan=0.0, send=0.03)
    shk = [(b * 0.5, 0.5 if b % 2 else 0.32) for b in range(beats * 2)]
    base.add(song.hits(drum_shaker, shk), -37, pan=-0.35, send=0.12)

    # ---------------- stem_groove: drums + walking bass + chord stabs
    groove = Mix(song)
    walk = [(bar * 4 + i, 0.9, m, (0.85, 0.7, 0.8, 0.7)[i]) for bar, line in enumerate(MAIN_WALK) for i, m in enumerate(line)]
    groove.add(song.notes(inst_bass, walk, jitter=4), -21, pan=0.0, send=0.04)
    comp = []
    for bar in range(song.bars):
        pushed_in = bar % 2 == 0  # odd bars anticipate the next downbeat (bar 16 -> bar 1 too)
        for s in [x for x in segs if x["bar"] == bar]:
            st, L, v = s["start"], s["length"], s["voicing"]
            if not (pushed_in and st == bar * 4):
                comp.append((st, 0.3, v, 0.62))
            comp.append((st + 1.5, 0.28, v, 0.72))
        if bar % 2 == 1:  # anticipate the next bar on the "and" of 4
            nxt = chord_at(segs, (bar + 1) * 4)
            comp.append((bar * 4 + 3.5, 0.45, nxt["voicing"], 0.7))
    groove.add(song.notes(inst_comp, comp, jitter=4, strum=0.012), -27, pan=0.4, send=0.15)
    kick = []
    snare = []
    ride = []
    pedal = []
    for bar in range(song.bars):
        b0 = bar * 4
        kick += [(b0, 0.85), (b0 + 2, 0.62)] + ([(b0 + 3.5, 0.35)] if bar % 2 else [])
        snare += [(b0 + 1, 0.75), (b0 + 3, 0.75), (b0 + 2.5, 0.2)] + ([(b0 + 3.5, 0.15)] if bar % 4 == 3 else [])
        ride += [(b0 + o, v) for o, v in ((0, 0.45), (1, 0.6), (1.5, 0.35), (2, 0.45), (3, 0.6), (3.5, 0.35))]
        pedal += [(b0 + 1, 0.35), (b0 + 3, 0.35)]
    groove.add(song.hits(drum_kick, kick), -23, pan=0.0, send=0.05)
    groove.add(song.hits(drum_brush, snare), -28, pan=-0.1, send=0.2)
    groove.add(song.hits(lambda v, r: drum_hat(v, r, 0.06), ride), -35, pan=0.3, send=0.15)
    groove.add(song.hits(lambda v, r: drum_hat(v, r, 0.02), pedal), -39, pan=0.25, send=0.1)
    groove.add(brush_swirl(song, song.rng), -43, pan=-0.15, send=0.1)

    # ---------------- stem_rush: 16th hats/shaker + whistle lead + brass stabs
    rush = Mix(song)
    hat16 = [(b * 0.25, (0.55, 0.28, 0.42, 0.3)[b % 4]) for b in range(beats * 4)]
    rush.add(song.hits(lambda v, r: drum_hat(v, r, 0.03), hat16, jitter=2), -35, pan=0.35, send=0.1)
    shk16 = [(b * 0.25, (0.3, 0.45, 0.32, 0.5)[b % 4]) for b in range(beats * 4)]
    rush.add(song.hits(drum_shaker, shk16, jitter=2), -39, pan=-0.45, send=0.1)
    lead = song.whistle(parse_melody(MAIN_MELODY, vel=0.85))
    lead = rush.add(lead, -20, pan=-0.05, send=0.25)
    rush.add_stereo(pingpong(lead, int(round(song.spb * 0.75)), fb=0.32), gain=0.28, send=0.2)
    brass = []
    for bar in range(song.bars):
        b0 = bar * 4
        pat = {0: [(1.5, 0.3)], 1: [(1.5, 0.3), (3.5, 0.5)], 2: [(1.5, 0.3)],
               3: [(2.0, 0.25), (2.5, 0.25), (3.5, 0.55)]}[bar % 4]
        for o, d in pat:
            v = chord_at(segs, b0 + o + 0.5 if o == 3.5 else b0 + o)["voicing"]
            brass.append((b0 + o, d, v + [v[-1] + 12], 0.8 if o == 3.5 else 0.68))
    rush.add(song.notes(inst_brass, brass, jitter=4, strum=0.006), -25, pan=0.2, send=0.25)
    toms = [(15 * 4 + 3.0, 0.7), (15 * 4 + 3.5, 0.6), (7 * 4 + 3.5, 0.55)]
    tom_trk = song.track()
    for i, (b, v) in enumerate(toms):
        song.place(tom_trk, drum_tom((165, 130, 150)[i], v, song.rng), song.sample(b, 3))
    rush.add(song.fold(tom_trk), -26, pan=-0.2, send=0.2)

    # small trims so each added layer audibly lifts the energy
    stems = {"stem_base": base.render(ir), "stem_groove": groove.render(ir) * dbg(1.0),
             "stem_rush": rush.render(ir) * dbg(2.0)}
    # common gain: loudest stem peaks at -6 dBFS and the full layered mix stays below -1 dBFS
    peak = max(np.max(np.abs(v)) for v in stems.values())
    total = np.max(np.abs(sum(stems.values())))
    g = min(dbg(-6.0) / peak, dbg(-1.0) / total)
    return {k: v * g for k, v in stems.items()}


def render_closing():
    """After-service / evening planning: 84 BPM lo-fi version of the theme."""
    song = Song(84, 16, swing=0.62, seed=84)
    segs = chord_segments(CLOSE_PROG)
    ir = make_ir(2.8, 2.0, seed=12, bright_hz=5000, dark_hz=1500)
    mix = Mix(song)
    ep = []
    for i, s in enumerate(segs):
        v, st, L, bar = s["voicing"], s["start"], s["length"], s["bar"]
        nxt = segs[(i + 1) % len(segs)]
        next_pushed = nxt["length"] == 4 and nxt["bar"] % 2 == 1
        if L == 4 and bar % 2 == 1:
            ep.append((st - 0.5, 4.3 if not next_pushed else 3.85, v, 0.5))  # lazy lo-fi anticipation
        else:
            ep.append((st, (L - 0.6) if next_pushed else (L - 0.15), v, 0.5))
        if L == 4 and bar % 4 == 2:
            ep.append((st + 2.5, 0.85 if next_pushed else 1.3, v[2:], 0.3))
    mix.add(cfilt(song.notes(inst_epiano, ep, jitter=9, strum=0.02), hi=3200), -19, pan=0.0, send=0.25,
            autopan=0.25 * song.lfo(0.25))
    mel = song.notes(inst_vibes, [(b, d * 1.3, m, v) for b, d, m, v in parse_melody(CLOSE_MELODY, vel=0.55)], jitter=8)
    mel = cfilt(mel * (1 - 0.25 * (0.5 + 0.5 * song.lfo(2))), hi=4500)
    mix.add(mel, -23, pan=-0.2, send=0.35)
    bass = []
    for i, s in enumerate(segs):
        r, st, L = s["root"], s["start"], s["length"]
        nxt = segs[(i + 1) % len(segs)]["root"]
        appr = nxt + (1 if s["bar"] % 2 else -1)
        if L == 4:
            bass += [(st, 1.3, r, 0.85), (st + 1.5, 0.45, fifth_below_or_above(r), 0.55), (st + 3, 0.8, appr, 0.6)]
        else:
            bass += [(st, 1.2, r, 0.8), (st + 1.5, 0.4, appr if st % 4 else r + 7, 0.5)]
    mix.add(song.notes(inst_softbass, bass, jitter=6), -20, pan=0.0, send=0.03)
    kick, snare, hats = [], [], []
    for bar in range(song.bars):
        b0 = bar * 4
        kick += [(b0, 0.85), (b0 + 2.5, 0.6)] + ([(b0 + 1.75, 0.35)] if bar % 2 else [])
        snare += [(b0 + 1, 0.7), (b0 + 3, 0.75)]
        hats += [(b0 + h * 0.5, (0.45, 0.25)[h % 2]) for h in range(8)]
    drums = sum(trk * dbg(lvl) / active_rms(trk) for trk, lvl in (
        (song.hits(drum_kick, kick), -22), (song.hits(drum_snare_lofi, snare), -27),
        (song.hits(lambda v, r: drum_hat(v, r, 0.035), hats), -36)))
    drums = cfilt(drums, hi=5000)
    drums = np.tanh(2.0 * drums / np.max(np.abs(drums)))  # dusty, squashed lo-fi kit
    mix.add(drums, -22, pan=0.0, send=0.08)
    crackle_trk = np.zeros(song.N)
    rng = song.rng
    for _ in range(int(song.N / SR * 9)):
        add_at(crackle_trk, crackle(rng, 800, 4000, tau=(0.0003, 0.0012)) * rng.exponential(0.5),
               rng.integers(song.N), wrap=True)
    hiss = cfilt(colored(song.N, rng, -3.0), lo=300, hi=6000)
    mix.add(cfilt(crackle_trk, hi=6000) + 0.15 * hiss * np.max(np.abs(crackle_trk)), -42, pan=0.0)
    out = mix.render(ir)
    # gentle tape wobble (whole cycles per loop) + warm low-pass + soft saturation
    n = np.arange(song.N)
    depth = 0.0012 * SR
    pos = n + depth * np.sin(TAU * song.bars * n / song.N)
    out = np.array([np.interp(pos, n, ch, period=song.N) for ch in out])
    out = cfilt(out, hi=7000)
    out = np.tanh(1.2 * out / np.max(np.abs(out))) / np.tanh(1.2)
    return norm(out, dbg(-5.0))  # denser than the other tracks: -5 dBFS peak matches their loudness


def render_menu():
    """Title / menu theme: 108 BPM, bright e-piano, vibes + glock melody, brushes."""
    song = Song(108, 16, swing=0.6, seed=108)
    segs = chord_segments(MENU_PROG)
    ir = make_ir(2.4, 1.7, seed=13)
    mix = Mix(song)
    ep = []
    for s in segs:
        v, st, L = s["voicing"], s["start"], s["length"]
        if L == 4:
            ep += [(st, 1.35, v, 0.62), (st + 1.5, 2.3, v[1:], 0.5)]
        else:
            ep += [(st, 1.35, v, 0.62), (st + 1.5, 0.45, v[1:], 0.45)]
    mix.add(cfilt(song.notes(inst_epiano, ep, jitter=6, strum=0.01), hi=7500), -19, pan=0.05, send=0.22,
            autopan=0.3 * song.lfo(0.5))
    mel_ev = parse_melody(MENU_MELODY, vel=0.8)
    mel = song.notes(inst_vibes, [(b, d * 1.4, m, v) for b, d, m, v in mel_ev], jitter=5)
    mel *= 1 - 0.25 * (0.5 + 0.5 * song.lfo(3))
    mix.add(mel, -19, pan=-0.2, send=0.3)
    gl = song.track()
    for b, d, m, v in mel_ev:
        if b >= 32:  # glockenspiel doubling in the second half for lift
            song.place(gl, glock(ns(1.0), mtof(m + 12), decay=0.35, vel=0.7) * v, song.sample(b, 4))
    mix.add(song.fold(gl), -31, pan=0.3, send=0.35)
    bass = []
    for i, s in enumerate(segs):
        r, st, L = s["root"], s["start"], s["length"]
        nxt = segs[(i + 1) % len(segs)]["root"]
        if L == 4:
            bass += [(st, 1.8, r, 0.85), (st + 2, 1.4, fifth_below_or_above(r), 0.7)]
            if s["bar"] % 2:
                bass.append((st + 3.5, 0.45, nxt + 1 if nxt + 1 <= 48 else nxt - 1, 0.5))
        else:
            bass += [(st, 1.8, r, 0.8)]
    mix.add(song.notes(inst_bass, bass, jitter=4), -21, pan=0.0, send=0.04)
    kick, snare, ride, shk = [], [], [], []
    for bar in range(song.bars):
        b0 = bar * 4
        kick += [(b0, 0.8), (b0 + 2, 0.6)]
        snare += [(b0 + 1, 0.65), (b0 + 3, 0.7), (b0 + 2.5, 0.18)]
        ride += [(b0 + o, v) for o, v in ((0, 0.45), (1, 0.6), (1.5, 0.35), (2, 0.45), (3, 0.6), (3.5, 0.35))]
        shk += [(b0 + h * 0.5, (0.3, 0.5)[h % 2]) for h in range(8)]
    mix.add(song.hits(drum_kick, kick), -25, pan=0.0, send=0.05)
    mix.add(song.hits(drum_brush, snare), -30, pan=-0.1, send=0.2)
    mix.add(song.hits(lambda v, r: drum_hat(v, r, 0.06), ride), -36, pan=0.3, send=0.15)
    mix.add(song.hits(drum_shaker, shk), -39, pan=-0.4, send=0.12)
    mix.add(brush_swirl(song, song.rng), -44, pan=-0.15, send=0.1)
    out = mix.render(ir)
    return norm(out, dbg(-3.0))


# =============================================================================
# Registry
# =============================================================================

# name -> generator(rng) -> float array; peak_db < -1 for intentionally subtle sounds
SFX = {
    "footstep_1": dict(fn=lambda r: footstep(r, 0.93), peak_db=-5.0),
    "footstep_2": dict(fn=lambda r: footstep(r, 1.0), peak_db=-5.0),
    "footstep_3": dict(fn=lambda r: footstep(r, 1.08), peak_db=-5.0),
    "pickup": dict(fn=sfx_pickup),
    "putdown": dict(fn=sfx_putdown),
    "drop_heavy": dict(fn=sfx_drop_heavy),
    "crate_take": dict(fn=sfx_crate_take),
    "chop_1": dict(fn=lambda r: chop(r, 0.94)),
    "chop_2": dict(fn=lambda r: chop(r, 1.0)),
    "chop_3": dict(fn=lambda r: chop(r, 1.07)),
    "sizzle_loop": dict(fn=sfx_sizzle_loop),
    "fryer_loop": dict(fn=sfx_fryer_loop),
    "ding": dict(fn=sfx_ding, peak_db=-2.0),
    "burn_warning": dict(fn=sfx_burn_warning),
    "coffee_brew_loop": dict(fn=sfx_coffee_brew_loop),
    "coffee_done": dict(fn=sfx_coffee_done),
    "fridge_open": dict(fn=sfx_fridge_open),
    "fridge_close": dict(fn=sfx_fridge_close),
    "door_bell": dict(fn=sfx_door_bell),
    "dish_clink": dict(fn=sfx_dish_clink),
    "dish_stack": dict(fn=sfx_dish_stack),
    "wash_loop": dict(fn=sfx_wash_loop),
    "dishwasher_loop": dict(fn=sfx_dishwasher_loop),
    "dishwasher_done": dict(fn=sfx_dishwasher_done, peak_db=-5.0),
    "cash_register": dict(fn=sfx_cash_register),
    "coin": dict(fn=sfx_coin),
    "crowd_loop": dict(fn=sfx_crowd_loop, peak_db=-3.0),
    "customer_happy": dict(fn=sfx_customer_happy, peak_db=-3.0),
    "customer_angry": dict(fn=sfx_customer_angry),
    "order_ready": dict(fn=sfx_order_ready),
    "serve": dict(fn=sfx_serve),
    "truck_engine_loop": dict(fn=sfx_truck_engine_loop),
    "truck_beep": dict(fn=sfx_truck_beep, peak_db=-7.0),
    "truck_horn": dict(fn=sfx_truck_horn),
    "alarm_loop": dict(fn=sfx_alarm_loop, peak_db=-6.0),
    "fire_loop": dict(fn=sfx_fire_loop),
    "extinguisher_loop": dict(fn=sfx_extinguisher_loop, peak_db=-2.0),
    "breakdown": dict(fn=sfx_breakdown),
    "repair_loop": dict(fn=sfx_repair_loop),
    "repair_done": dict(fn=sfx_repair_done),
    "mop_loop": dict(fn=sfx_mop_loop),
    "splash": dict(fn=sfx_splash),
    "glass_break": dict(fn=sfx_glass_break),
    "ui_click": dict(fn=sfx_ui_click, peak_db=-4.0),
    "ui_hover": dict(fn=sfx_ui_hover, peak_db=-12.0),
    "ui_confirm": dict(fn=sfx_ui_confirm, peak_db=-2.0),
    "ui_back": dict(fn=sfx_ui_back, peak_db=-3.0),
    "open_sign": dict(fn=sfx_open_sign),
    "day_end": dict(fn=sfx_day_end),
    "build_place": dict(fn=sfx_build_place),
    "build_lift": dict(fn=sfx_build_lift),
    "construct": dict(fn=sfx_construct),
    "ping": dict(fn=sfx_ping),
    "trash": dict(fn=sfx_trash),
    "conveyor_loop": dict(fn=sfx_conveyor_loop),
    "grabber": dict(fn=sfx_grabber),
    "timer_ring": dict(fn=sfx_timer_ring),
    "whoosh": dict(fn=sfx_whoosh, peak_db=-2.0),
    "error": dict(fn=sfx_error),
    "spoil": dict(fn=sfx_spoil),
    "money_spend": dict(fn=sfx_money_spend),
    "level_up": dict(fn=sfx_level_up),
}

MUSIC = ["stem_base", "stem_groove", "stem_rush", "music_closing", "music_menu"]


def build_sfx(name):
    spec = SFX[name]
    x = spec["fn"](rng_for(name))
    if name.endswith("_loop"):
        x = finalize_loop(x, spec.get("peak_db", -1.0))
    else:
        x = finalize_oneshot(x, spec.get("peak_db", -1.0))
    write_wav(SFX_DIR / f"{name}.wav", x)
    return len(x) / SR


def encode_music(name, x):
    """Write one music loop and report how seamless it is before and after
    the (lossy) Vorbis round trip."""
    raw_seam = seam_score(x)
    path = MUSIC_DIR / f"{name}.ogg"
    write_ogg(path, x)
    y = decode_ogg(path)
    err = np.abs(y - x) if y.shape == x.shape else None
    msg = f"render seam {raw_seam:.2f}"
    if err is not None:
        seam_err = max(err[:, :64].max(), err[:, -64:].max())
        msg += (f", Vorbis error at loop point {20 * np.log10(seam_err + 1e-12):.1f} dBFS"
                f" vs {20 * np.log10(np.percentile(err, 99.99) + 1e-12):.1f} dBFS (99.99th pct) elsewhere")
    print(f"  music {name:22s} {x.shape[1] / SR:6.3f}s  {msg}")
    if raw_seam >= 1.0:
        print(f"  WARNING: {name} render is not seamless")
    return x.shape[1] / SR


def build_music(names):
    out = {}
    if any(n.startswith("stem_") for n in names):
        stems = render_main_stems()  # always rendered together (shared gain)
        for k, v in stems.items():
            out[k] = encode_music(k, v)
    if "music_closing" in names:
        out["music_closing"] = encode_music("music_closing", render_closing())
    if "music_menu" in names:
        out["music_menu"] = encode_music("music_menu", render_menu())
    return out


# =============================================================================
# Verification
# =============================================================================

def read_wav(path):
    with wave.open(str(path), "rb") as w:
        info = (w.getnchannels(), w.getsampwidth(), w.getframerate())
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
    return info, data


def decode_ogg(path):
    cmd = [ffmpeg_bin(), "-hide_banner", "-loglevel", "error", "-i", str(path),
           "-f", "f32le", "-ac", "2", "-ar", str(SR), "pipe:1"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(float).reshape(-1, 2).T


def seam_score(x):
    """Click detector for the loop point (end -> start).  Compares the
    wrap-around step with the neighbouring sample steps, and the curvature
    across the seam with the file's own 99.5th-percentile curvature.
    < 1.0 means the seam looks like any other place in the file."""
    worst = 0.0
    for ch in np.atleast_2d(x):
        w = np.concatenate([ch[-16:], ch[:16]])  # signal as heard across the loop point
        d1 = np.abs(np.diff(w))
        step = d1[15]
        local = max(np.max(np.delete(d1, 15)), np.percentile(np.abs(np.diff(ch)), 50)) + 1e-9
        d2 = np.abs(np.diff(w, 2))
        curv = max(d2[14], d2[15])
        ref2 = max(np.percentile(np.abs(np.diff(ch, 2)), 99.5), np.max(np.delete(d2, [14, 15]))) + 1e-9
        worst = max(worst, step / (1.25 * local), curv / ref2)
    return worst


SEAM_FLOOR_DB = -40.0  # Vorbis q5 quantization error in these files peaks around -30 dBFS


def seam_excess_db(x):
    """How much bigger (dBFS) the loop-point step is than the largest
    neighbouring step - i.e. the size of any click added at the seam."""
    worst = 0.0
    for ch in np.atleast_2d(x):
        d1 = np.abs(np.diff(np.concatenate([ch[-16:], ch[:16]])))
        worst = max(worst, d1[15] - np.max(np.delete(d1, 15)))
    return 20 * np.log10(max(worst, 1e-6))


def verify(names=None):
    ok = True
    print("\n=== SFX (audio/sfx) ===")
    print(f"{'file':28s} {'fmt':14s} {'dur(s)':>7s} {'peak dBFS':>9s} {'DC':>8s}  check")
    total = 0
    for name in SFX:
        if names and name not in names:
            continue
        p = SFX_DIR / f"{name}.wav"
        if not p.exists():
            print(f"{name + '.wav':28s} MISSING")
            ok = False
            continue
        total += p.stat().st_size
        (ch, sw, sr), x = read_wav(p)
        peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        dc = float(np.mean(x))
        fmt_ok = (ch, sw, sr) == (1, 2, SR)
        msgs = []
        good = fmt_ok and peak < -0.5 and abs(dc) < 2e-3
        if name.endswith("_loop"):
            s = seam_score(x)
            msgs.append(f"seam {s:.2f}")
            good &= s < 1.0
        else:
            edge = max(abs(x[0]), abs(x[-1]))
            msgs.append(f"edges {edge:.4f}")
            good &= edge < 2e-3
        ok &= good
        print(f"{name + '.wav':28s} {f'{ch}ch/{sw * 8}bit/{sr}':14s} {len(x) / SR:7.3f} {peak:9.2f} {dc:8.5f}  "
              f"{' '.join(msgs)} {'OK' if good else 'FAIL'}")
    print(f"SFX total size: {total / 1e6:.2f} MB")

    print("\n=== Music (audio/music, decoded with ffmpeg) ===")
    total = 0
    decoded = {}
    for name in MUSIC:
        if names and name not in names:
            continue
        p = MUSIC_DIR / f"{name}.ogg"
        if not p.exists():
            print(f"{name}.ogg MISSING")
            ok = False
            continue
        total += p.stat().st_size
        x = decode_ogg(p)
        decoded[name] = x
        peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        s = seam_score(x)
        xs = seam_excess_db(x)
        good = peak < 0 and x.shape[0] == 2 and (s < 1.0 or xs < SEAM_FLOOR_DB)
        ok &= good
        print(f"{name + '.ogg':22s} {x.shape[0]}ch {x.shape[1]:9d} samples {x.shape[1] / SR:8.3f}s "
              f"peak {peak:6.2f} dBFS  seam {s:.2f} (excess step {xs:6.1f} dBFS)  "
              f"{p.stat().st_size / 1e6:.2f} MB  {'OK' if good else 'FAIL'}")
    print(f"Music total size: {total / 1e6:.2f} MB")
    stems = [decoded[k] for k in ("stem_base", "stem_groove", "stem_rush") if k in decoded]
    if len(stems) == 3:
        lens = {s.shape[1] for s in stems}
        expect = int(round(16 * 4 * SR * 60 / 112))
        same = len(lens) == 1 and lens.pop() == expect
        mix_peak = 20 * np.log10(np.max(np.abs(sum(stems))) + 1e-12)
        print(f"stems identical length ({expect} samples = 16 bars @112 BPM): {'OK' if same else 'FAIL'}; "
              f"base+groove+rush peak {mix_peak:.2f} dBFS ({'OK' if mix_peak < 0 else 'CLIPS'}); "
              f"layered seam {seam_score(sum(stems)):.2f}")
        ok &= same and mix_peak < 0
    print("\nALL CHECKS PASSED" if ok else "\nSOME CHECKS FAILED")
    return ok


# =============================================================================
# Main
# =============================================================================

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--sfx", action="store_true", help="only (re)generate sound effects")
    ap.add_argument("--music", action="store_true", help="only (re)generate music")
    ap.add_argument("--only", default="", help="comma separated asset names")
    ap.add_argument("--verify", action="store_true", help="only verify existing files")
    ap.add_argument("--list", action="store_true", help="list asset names")
    args = ap.parse_args(argv)

    if args.list:
        print("\n".join(list(SFX) + MUSIC))
        return 0
    only = [s.strip() for s in args.only.split(",") if s.strip()]
    unknown = [s for s in only if s not in SFX and s not in MUSIC]
    if unknown:
        sys.exit(f"unknown asset(s): {', '.join(unknown)}  (see --list)")
    if args.verify:
        return 0 if verify(only or None) else 1

    do_sfx = not args.music or args.sfx
    do_music = not args.sfx or args.music
    sfx_names = [n for n in SFX if (not only or n in only)] if do_sfx else []
    music_names = [n for n in MUSIC if (not only or n in only)] if do_music else []

    t0 = time.time()
    for name in sfx_names:
        d = build_sfx(name)
        print(f"  sfx   {name:22s} {d:6.3f}s")
    if music_names:
        build_music(music_names)
    print(f"generated in {time.time() - t0:.1f}s")
    return 0 if verify((sfx_names + music_names) or None) else 1


if __name__ == "__main__":
    sys.exit(main())
