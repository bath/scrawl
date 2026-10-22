#!/usr/bin/env bash
# Runs the checked-in bundle through the shipped Scrawl binary and sends the same audio to Hex whole.
# input.scrawl/audio.wav is seven phrases at one normal level, 1.5 s apart (macOS `say`, noise seed 2).
#
# Needs: Hex running with a model ready, Scrawl, python3, curl. Run from this folder:
#   SCRAWL=/Applications/Scrawl.app/Contents/MacOS/scrawl MODEL=parakeet_unified_en ./repro.sh
set -euo pipefail
SCRAWL=${SCRAWL:-/Applications/Scrawl.app/Contents/MacOS/scrawl}
MODEL=${MODEL:-parakeet_unified_en}
HEX_DIR=${HEX_APPLICATION_SUPPORT_DIR:-$HOME/Library/Application Support/voice-control}
cd "$(dirname "$0")"

"$SCRAWL" --version
for engine in hex apple; do
  mkdir -p "out-$engine"
  rm -rf "out-$engine/bundle.scrawl"
  "$SCRAWL" reprocess input.scrawl --transcriber "$engine" --out "out-$engine/bundle.scrawl" > "out-$engine/$engine.log" 2>&1
  cp "out-$engine/bundle.scrawl/scrawl.json" "out-$engine/bundle.scrawl/summary.md" "out-$engine/"
  rm -rf "out-$engine/bundle.scrawl"
  python3 -c "import json, sys; t = json.load(open(sys.argv[1]))['transcript']; print(json.dumps({'source': t['source'], 'text': t['text'], 'segments': t['segments']}, indent=1))" \
    "out-$engine/scrawl.json" > "out-$engine/transcript-$engine.json"
done

mkdir -p out-hex-whole-file
PORT=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['port'])" "$HEX_DIR/local-api.json")
TOKEN=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['token'])" "$HEX_DIR/local-api.json")
curl -s -X POST "http://127.0.0.1:$PORT/transcriptions?model=$MODEL&language=en" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: audio/wav" \
  --data-binary @input.scrawl/audio.wav > out-hex-whole-file/transcript-hex-whole-file.json

for engine in hex apple; do
  printf '%-22s %s\n' "scrawl $engine" "$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['text'])" "out-$engine/transcript-$engine.json")"
done
printf '%-22s %s\n' "hex, whole file" "$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['transcript'])" out-hex-whole-file/transcript-hex-whole-file.json)"
