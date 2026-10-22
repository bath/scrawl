# usage: chart.py WAV CLIPS_JSON MISSED_SPANS("a-b,a-b") TITLE OUT.svg
# Draws 50 ms window RMS (what Scrawl's speech_islands measures), the limit it computes,
# the clips Scrawl sends to Hex (green) and speech it never sends (red).
import sys, wave, struct, math, json, html
wav, clips_path, missed_arg, title, out = sys.argv[1:6]
w = wave.open(wav); n = w.getnframes()
s = [x / 32768 for x in struct.unpack('<%dh' % n, w.readframes(n))]
rms = [math.sqrt(sum(x * x for x in s[i:i + 800]) / len(s[i:i + 800])) for i in range(0, n, 800)]
floor = sorted(rms)[len(rms) // 10]
limit = min(max(floor * 3, 0.005), 0.02)
clips = json.load(open(clips_path))
missed = [tuple(int(v) for v in p.split('-')) for p in missed_arg.split(',') if p]
dur = n * 1000 / 16000

W, H, L, R, T, B = 1200, 380, 70, 20, 56, 54
pw, ph = W - L - R, H - T - B
top = max(0.03, max(rms) * 1.05)
X = lambda ms: L + ms / dur * pw
Y = lambda v: T + ph - min(v, top) / top * ph
o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Helvetica, Arial, sans-serif">',
     f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
     f'<text x="{L}" y="24" font-size="17" font-weight="600" fill="#0f172a">{html.escape(title)}</text>',
     f'<text x="{L}" y="44" font-size="13" fill="#475569">50 ms window RMS · noise floor {floor:.4f} · limit = 3 × floor = {limit:.4f}</text>']
for a, b in missed:
    o.append(f'<rect x="{X(a):.1f}" y="{T}" width="{X(b) - X(a):.1f}" height="{ph}" fill="#dc2626" fill-opacity="0.13"/>')
for a, b in clips:
    a, b = max(0, a - 200), min(dur, b + 200)
    o.append(f'<rect x="{X(a):.1f}" y="{T}" width="{X(b) - X(a):.1f}" height="{ph}" fill="#16a34a" fill-opacity="0.18"/>')
bw = pw / len(rms)
for i, v in enumerate(rms):
    c = '#334155' if v > limit else '#94a3b8'
    o.append(f'<rect x="{L + i * bw:.2f}" y="{Y(v):.1f}" width="{max(bw - 0.6, 0.6):.2f}" height="{T + ph - Y(v):.1f}" fill="{c}"/>')
o.append(f'<line x1="{L}" x2="{L + pw}" y1="{Y(limit):.1f}" y2="{Y(limit):.1f}" stroke="#b45309" stroke-width="1.5" stroke-dasharray="6 4"/>')
o.append(f'<text x="{L + pw - 4}" y="{Y(limit) - 6:.1f}" font-size="12" text-anchor="end" fill="#b45309">limit {limit:.4f}</text>')
o.append(f'<line x1="{L}" x2="{L + pw}" y1="{T + ph}" y2="{T + ph}" stroke="#cbd5e1"/>')
step = 5000 if dur > 20000 else 1000
for t in range(0, int(dur) + 1, step):
    o.append(f'<text x="{X(t):.1f}" y="{T + ph + 18}" font-size="12" text-anchor="middle" fill="#64748b">{t // 1000} s</text>')
for v in (0.01, 0.02):
    if v < top:
        o.append(f'<text x="{L - 8}" y="{Y(v) + 4:.1f}" font-size="12" text-anchor="end" fill="#64748b">{v:.2f}</text>')
ly = H - 14
o.append(f'<rect x="{L}" y="{ly - 11}" width="14" height="14" fill="#16a34a" fill-opacity="0.35"/><text x="{L + 20}" y="{ly}" font-size="13" fill="#334155">sent to Hex (clip + 200 ms pad)</text>')
o.append(f'<rect x="{L + 250}" y="{ly - 11}" width="14" height="14" fill="#dc2626" fill-opacity="0.3"/><text x="{L + 270}" y="{ly}" font-size="13" fill="#334155">speech Scrawl never sends</text>')
o.append(f'<rect x="{L + 470}" y="{ly - 11}" width="14" height="14" fill="#94a3b8"/><text x="{L + 490}" y="{ly}" font-size="13" fill="#334155">window under the limit</text>')
o.append('</svg>')
open(out, 'w').write('\n'.join(o))
