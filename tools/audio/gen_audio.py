"""Procedural (computed) audio for the PoC: every sound effect + the elevator-music loop are synthesized here
with numpy, no samples and no AI audio platforms (owner rule: the final audio will come from the owner's Suno account;
drop files with the same names into assets/audio/ to replace these).

Run:  python3 tools/audio/gen_audio.py      (needs numpy + ffmpeg)  ->  assets/audio/<name>.ogg
"""
import os
import subprocess
import tempfile
import wave
import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, sus=None):
    """Simple ADSR (seconds) over n samples."""
    out = np.zeros(n)
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    S = max(0, n - A - D - R) if sus is None else int(sus * SR)
    i = 0
    seg = [(A, np.linspace(0, 1, max(A, 1))), (D, np.linspace(1, s, max(D, 1))), (S, np.full(S, s)), (R, np.linspace(s, 0, max(R, 1)))]
    for ln, curve in seg:
        ln = min(ln, n - i)
        if ln <= 0:
            continue
        out[i:i + ln] = curve[:ln]
        i += ln
    return out


def expdec(n, k):
    return np.exp(-k * np.arange(n) / SR)


def sweep(f0, f1, dur, shape="sine", curve="exp"):
    t = t_(dur)
    if curve == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    ph = 2 * np.pi * np.cumsum(f) / SR
    return osc(ph, shape)


def osc(ph, shape):
    if shape == "sine":
        return np.sin(ph)
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.6
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if shape == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    raise ValueError(shape)


def tone(f, dur, shape="sine", vib=0.0, vib_rate=5.5):
    t = t_(dur)
    fr = f * (1 + vib * np.sin(2 * np.pi * vib_rate * t))
    return osc(2 * np.pi * np.cumsum(fr) / SR, shape)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def onepole_lp(x, cutoff):
    # vectorised-ish IIR via scipy if present, else python loop
    try:
        from scipy.signal import lfilter
        a = np.exp(-2 * np.pi * cutoff / SR)
        return lfilter([1 - a], [1, -a], x)
    except ImportError:
        return lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return onepole_lp(x, hi) - onepole_lp(x, lo)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(x, before=0.0, after=0.0):
    return np.concatenate([np.zeros(int(before * SR)), x, np.zeros(int(after * SR))])


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write(name, x, peak=0.85):
    os.makedirs(OUT, exist_ok=True)
    x = norm(x, peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.unlink(tmp)
    print(f"{name}.ogg  {len(x) / SR:.2f}s")


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


# ------------------------------------------------------------------ sound effects
def sfx():
    # climb: hand slap on concrete + tiny effort grunt
    n = int(0.11 * SR)
    slap = bandpass(noise(0.11), 600, 4000) * expdec(n, 45)
    grunt = tone(150, 0.11, "saw", 0.04, 30) * env(n, 0.005, 0.05, 0.3, 0.04)
    write("climb", mix(slap, onepole_lp(grunt, 900) * 0.5), 0.7)
    # shimmy: quick fabric swish
    n = int(0.12 * SR)
    write("shimmy", bandpass(noise(0.12), 1500, 7000) * env(n, 0.02, 0.05, 0.4, 0.05), 0.5)
    # bump: dull thud
    n = int(0.16 * SR)
    write("bump", mix(sweep(140, 60, 0.16) * expdec(n, 25), onepole_lp(noise(0.16), 400) * expdec(n, 40) * 0.6), 0.7)
    # window: sash sliding up (squeaky)
    n = int(0.26 * SR)
    sq = sweep(420, 900, 0.26, "square", "lin") * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t_(0.26))))
    write("window", onepole_lp(sq, 2500) * env(n, 0.01, 0.05, 0.6, 0.06), 0.5)
    # throw: whoosh
    n = int(0.32 * SR)
    wh = bandpass(noise(0.32), 300, 2500) * np.sin(np.linspace(0, np.pi, n)) ** 2
    write("throw", wh, 0.7)
    write("whoosh", bandpass(noise(0.2), 800, 5000) * np.sin(np.linspace(0, np.pi, int(0.2 * SR))) ** 2, 0.45)
    # hit: cartoon BONK + boing
    n = int(0.45 * SR)
    bonk = sweep(700, 160, 0.12) * expdec(int(0.12 * SR), 30)
    boing = tone(220, 0.45, "sine", 0.18, 16) * expdec(n, 7)
    write("hit", mix(bonk, onepole_lp(noise(0.05), 3000) * 0.7, pad(boing, 0.04) * 0.6), 0.9)
    # pop: confetti box bursts
    n = int(0.25 * SR)
    write("pop", mix(onepole_lp(noise(0.25), 5000) * expdec(n, 30), sweep(1200, 2400, 0.08) * expdec(int(0.08 * SR), 40) * 0.5), 0.8)
    # coo: pigeon
    c1 = tone(560, 0.22, "sine", 0.06, 22) * env(int(0.22 * SR), 0.03, 0.08, 0.5, 0.08)
    write("coo", mix(c1, pad(c1 * 0.8, 0.25)), 0.5)
    # promote: rising arpeggio + sparkle
    parts = []
    for i, m in enumerate([72, 76, 79, 84, 88]):
        d = 0.32 if i == 4 else 0.12
        x = mix(tone(note(m), d, "square") * 0.4, tone(note(m) * 2, d, "sine") * 0.3) * env(int(d * SR), 0.005, 0.05, 0.6, 0.06)
        parts.append(pad(x, i * 0.085))
    spark = mix(*[pad(tone(note(96 + k), 0.08) * expdec(int(0.08 * SR), 25) * 0.3, 0.4 + k * 0.05) for k in [0, 4, 7, 12]])
    write("promote", mix(*parts, spark), 0.8)
    # intern: slide whistle down + boing
    sw = sweep(1600, 300, 0.7, "sine") * env(int(0.7 * SR), 0.02, 0.1, 0.8, 0.1)
    write("intern", mix(sw * 0.7, pad(tone(180, 0.35, "sine", 0.2, 14) * expdec(int(0.35 * SR), 8), 0.65)), 0.8)
    # ding: elevator chime (ding ... dong)
    def bell(f, d):
        k = int(d * SR)
        return mix(tone(f, d) * expdec(k, 3), tone(f * 2.76, d) * expdec(k, 7) * 0.4, tone(f * 5.4, d) * expdec(k, 12) * 0.2)
    write("ding", mix(bell(note(76), 1.2), pad(bell(note(72), 1.4), 0.38)), 0.7)
    # victory fanfare (brassy saw, lowpassed)
    seq = [(67, 0.14), (72, 0.14), (76, 0.14), (79, 0.3), (76, 0.14), (79, 0.9)]
    out, at = [], 0.0
    for m, d in seq:
        x = mix(tone(note(m), d + 0.05, "saw", 0.006), tone(note(m - 12), d + 0.05, "saw") * 0.5)
        x = onepole_lp(x, 2600) * env(len(x), 0.02, 0.05, 0.75, 0.08)
        out.append(pad(x, at))
        at += d
    drum = pad(onepole_lp(noise(0.5), 1800) * expdec(int(0.5 * SR), 6) * 0.5, at - 0.9)
    write("victory", mix(*out, drum), 0.85)
    # game over: sad trombone (wah wah wah waaaah)
    out, at = [], 0.0
    for m, d, v in [(58, 0.42, 0.0), (57, 0.42, 0.0), (56, 0.42, 0.0), (55, 1.3, 0.025)]:
        x = tone(note(m), d, "saw", v, 6.0)
        x = onepole_lp(x, 1100) * env(len(x), 0.04, 0.1, 0.8, 0.12)
        out.append(pad(x, at))
        at += d + 0.04
    write("gameover", mix(*out), 0.85)
    # fall: long descending whistle
    write("fall", sweep(1400, 220, 1.3, "sine") * env(int(1.3 * SR), 0.02, 0.2, 0.8, 0.3), 0.6)
    # click
    write("click", onepole_lp(noise(0.03), 6000) * expdec(int(0.03 * SR), 120), 0.5)


# ------------------------------------------------------------------ elevator music loop
def epiano(f, dur):
    """FM electric piano: decaying modulation index."""
    t = t_(dur)
    n = len(t)
    idx = 2.2 * np.exp(-t * 6)
    mod = np.sin(2 * np.pi * f * t) * idx
    car = np.sin(2 * np.pi * f * t + mod)
    return car * np.exp(-t * 2.2) * env(n, 0.003, 0.05, 1.0, 0.08)


def vibes(f, dur):
    t = t_(dur)
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 8)
    return x * np.exp(-t * 3.0) * (1 + 0.25 * np.sin(2 * np.pi * 5.5 * t))


def music():
    bpm = 112
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    N = int(total * SR) + 1
    tail = int(3 * SR)
    buf = np.zeros(N + tail)

    def put(x, at, gain=1.0):
        i = int(at * SR)
        buf[i:i + len(x)] += x * gain

    # chords (MIDI voicings), 1 per bar: a cheerful I-vi-ii-V loop with a IV turnaround
    prog = [
        ("F", 53, [57, 60, 64, 65]), ("Dm", 50, [57, 60, 62, 65]), ("Gm", 55, [58, 62, 65, 67]), ("C", 48, [58, 62, 64, 67]),
        ("F", 53, [57, 60, 64, 65]), ("Dm", 50, [57, 60, 62, 65]), ("Bb", 46, [57, 58, 62, 65]), ("C", 48, [58, 60, 64, 67]),
    ] * 2
    for b, (_, root, chord) in enumerate(prog):
        t0 = b * 4 * beat
        # comping: bossa-ish hits
        for off, ln, g in [(0, 1.2, 0.5), (1.5, 0.5, 0.35), (2.5, 1.2, 0.42)]:
            for m in chord:
                put(epiano(note(m), ln * beat + 0.2), t0 + off * beat, g * 0.22)
        # bass: root, fifth, with pickup
        for off, m, ln in [(0, root, 1.4), (1.5, root + 7, 0.5), (2, root + 7, 1.4), (3.5, root + 12 - 1 if b % 4 == 3 else root + 5, 0.5)]:
            x = tone(note(m - 12), ln * beat, "sine") + 0.25 * tone(note(m - 12) * 2, ln * beat, "tri")
            put(x * env(len(x), 0.01, 0.1, 0.7, 0.06), t0 + off * beat, 0.5)
        # brushes: swung eighths + soft rim on 2/4 "and"
        for k in range(8):
            sw = 0.0 if k % 2 == 0 else 0.16 * beat
            x = bandpass(noise(0.08), 3000, 9000) * expdec(int(0.08 * SR), 40)
            put(x, t0 + k * 0.5 * beat + sw, 0.07 if k % 2 == 0 else 0.045)
        for off in (1, 3):
            x = bandpass(noise(0.05), 1200, 5000) * expdec(int(0.05 * SR), 60)
            put(x, t0 + off * beat, 0.09)
        put(onepole_lp(noise(0.1), 200) * expdec(int(0.1 * SR), 30), t0, 0.25)
    # vibraphone melody: an innocent, slightly smug tune (two 8-bar phrases)
    mel = [
        [(0, 72, 1), (1, 74, 0.5), (1.5, 76, 1.5), (3, 72, 1)],
        [(0, 74, 1.5), (1.5, 72, 0.5), (2, 69, 2)],
        [(0, 70, 1), (1, 72, 0.5), (1.5, 74, 1.5), (3, 77, 1)],
        [(0, 76, 3), (3, 74, 0.5), (3.5, 72, 0.5)],
        [(0, 72, 1), (1, 74, 0.5), (1.5, 76, 1.5), (3, 79, 1)],
        [(0, 77, 1.5), (1.5, 76, 0.5), (2, 74, 2)],
        [(0, 74, 1), (1, 72, 0.5), (1.5, 70, 1.5), (3, 69, 1)],
        [(0, 67, 2), (2, 72, 2)],
    ]
    for rep in range(2):
        for b, notes in enumerate(mel):
            t0 = (rep * 8 + b) * 4 * beat
            for off, m, ln in notes:
                if rep == 1 and b == 7:
                    m = {67: 64, 72: 65}.get(m, m)    # turnaround back into the loop
                put(vibes(note(m), ln * beat + 0.6), t0 + off * beat, 0.32)
    # wrap the tail into the start for a seamless loop
    loop = buf[:N].copy()
    loop[:tail] += buf[N:N + tail]
    loop = onepole_lp(loop, 9000)
    write("music_elevator", loop, 0.7)


if __name__ == "__main__":
    sfx()
    music()
