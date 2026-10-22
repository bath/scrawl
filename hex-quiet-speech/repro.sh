#!/usr/bin/env bash
# Shows Scrawl's Hex transcriber dropping quiet speech, with the shipped scrawl binary.
#
# Needs: macOS `say`, python3, ffmpeg, curl, Hex running with a model ready, and Scrawl.
# Writes everything into ./out. Run from any empty folder:
#   SCRAWL=/Applications/Scrawl.app/Contents/MacOS/scrawl MODEL=parakeet_unified_en ./repro.sh
set -euo pipefail
SCRAWL=${SCRAWL:-/Applications/Scrawl.app/Contents/MacOS/scrawl}
MODEL=${MODEL:-parakeet_unified_en}
HEX_DIR=${HEX_APPLICATION_SUPPORT_DIR:-$HOME/Library/Application Support/voice-control}
mkdir -p out/input.scrawl && cd out

# 1. Audio: one sentence at a normal level, then one at half the level, over a 0.004 RMS floor.
say -o loud.wav  --data-format=LEI16@16000 "When I pick a different template and replace the dates, the feed lists every single milestone change."
say -o quiet.wav --data-format=LEI16@16000 "It should say that the template switched, and list which milestones changed, rather than each one on its own line."
python3 - <<'EOF'
import wave, struct, random, math
def read(p):
    w = wave.open(p); n = w.getnframes()
    return [x / 32768 for x in struct.unpack('<%dh' % n, w.readframes(n))]
rms = lambda a: math.sqrt(sum(x * x for x in a) / len(a))
loud, quiet = read('loud.wav'), read('quiet.wav')
random.seed(1)
gain_loud, gain_quiet = 0.012 / rms(loud), 0.006 / rms(quiet)
sig = [0.0] * 8000 + [x * gain_loud for x in loud] + [0.0] * 6400 \
    + [x * gain_quiet for x in quiet] + [0.0] * 8000
sig = [x + random.gauss(0, 0.004) for x in sig]
o = wave.open('input.scrawl/audio.wav', 'wb'); o.setnchannels(1); o.setsampwidth(2); o.setframerate(16000)
o.writeframes(struct.pack('<%dh' % len(sig), *[max(-32768, min(32767, round(x * 32768))) for x in sig]))
EOF

# 2. A bundle around it: a blank video and a manifest with nothing else in it.
ffmpeg -loglevel error -y -f lavfi -i color=c=gray:s=1280x800:r=10 -i input.scrawl/audio.wav \
  -shortest -c:v libx264 -pix_fmt yuv420p -c:a aac input.scrawl/recording.mp4
DUR=$(python3 -c "import wave; w = wave.open('input.scrawl/audio.wav'); print(w.getnframes() * 1000 // 16000)")
cat > input.scrawl/scrawl.json <<EOF
{"version": 1, "id": "repro", "createdAtMs": 0, "durationMs": $DUR,
 "target": {"mode": "display", "app": "Repro", "bundleId": "example.repro", "windowTitle": "Repro", "displayId": 1,
            "frame": {"x": 0.0, "y": 0.0, "width": 1280.0, "height": 800.0, "scale": 1.0}},
 "transcript": {"source": "none", "segments": [], "words": [], "text": ""},
 "strokes": [], "marks": [], "events": [], "keyframes": [], "windows": [], "cursor": [],
 "video": "recording.mp4", "videoOffsetMs": 0, "audio": "audio.wav", "contactSheet": "contact-sheet.png"}
EOF

# 3. The same bundle through Scrawl's two transcribers.
"$SCRAWL" --version
for engine in hex apple; do
  rm -rf "$engine.scrawl"
  "$SCRAWL" reprocess input.scrawl --transcriber "$engine" --out "$engine.scrawl" > "$engine.log" 2>&1
  python3 -c "import json, sys; t = json.load(open(sys.argv[1]))['transcript']; print(json.dumps({'source': t['source'], 'text': t['text'], 'segments': t['segments']}, indent=1))" \
    "$engine.scrawl/scrawl.json" > "transcript-$engine.json"
done

# 4. The same audio file, whole, in one request to Hex.
PORT=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['port'])" "$HEX_DIR/local-api.json")
TOKEN=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['token'])" "$HEX_DIR/local-api.json")
curl -s -X POST "http://127.0.0.1:$PORT/transcriptions?model=$MODEL&language=en" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: audio/wav" \
  --data-binary @input.scrawl/audio.wav > transcript-hex-whole-file.json

for f in transcript-hex.json transcript-apple.json; do
  printf '%-34s %s\n' "$f" "$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['text'])" "$f")"
done
printf '%-34s %s\n' transcript-hex-whole-file.json "$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['transcript'])" transcript-hex-whole-file.json)"
