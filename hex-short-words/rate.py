# How often does each phrase's island fall under MIN_ISLAND_MS (120 ms), over 200 noise draws?
import wave, struct, random, math, json, sys
import numpy as np
def read(p):
    w = wave.open(p); n = w.getnframes(); return np.frombuffer(w.readframes(n), '<i2') / 32768
texts = ["Open the settings page.", "Yes.", "No.", "Okay.", "Delete it.", "Wait.", "Then click save."]
parts, spans, pos = [np.zeros(8000)], [], 8000
for i, t in enumerate(texts):
    a = read(f'phrases/p{i}.wav'); g = 0.012 / math.sqrt((a * a).mean())
    v = np.nonzero(np.abs(a) > 0.002)[0]; a = a[v[0]:v[-1] + 1] * g
    spans.append((pos * 1000 // 16000, (pos + len(a)) * 1000 // 16000)); parts += [a, np.zeros(24000)]; pos += len(a) + 24000
clean = np.concatenate(parts)
dropped = {t: 0 for t in texts}; N = 200
for seed in range(N):
    x = clean + np.random.default_rng(seed).normal(0, 0.004, len(clean))
    x = np.clip(np.round(x * 32768), -32768, 32767) / 32768
    win = 800; r = np.sqrt((x[:len(x) // win * win].reshape(-1, win) ** 2).mean(1))
    thr = min(max(np.sort(r)[len(r) // 10] * 3, 0.005), 0.02)
    isl = []
    for i, l in enumerate(r):
        if l <= thr: continue
        a, b = i * 50, i * 50 + 50
        if isl and a - isl[-1][1] < 350: isl[-1][1] = b
        else: isl.append([a, b])
    kept = [(a, b) for a, b in isl if b - a >= 120]
    for t, (s0, s1) in zip(texts, spans):
        if not any(a < s1 + 200 and b > s0 - 200 for a, b in kept): dropped[t] += 1
for t in texts: print(f"{t:26s} dropped in {dropped[t]:3d} / {N} noise draws")
