#!/usr/bin/env bash
# Local text-to-speech for scratch VO. Neither engine needs root.
#   piper     — neural TTS, for narrator / in-character lines
#   espeak-ng — deliberately synthetic, candidate voice for the demo phone
#               (which is not a person and nobody has vouched for it)
set -euo pipefail
cd "$(dirname "$0")"

python3 -m venv tts-venv
./tts-venv/bin/pip install -q piper-tts

mkdir -p voices && cd voices
B=https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US
for v in ryan/high/en_US-ryan-high joe/medium/en_US-joe-medium \
         hfc_male/medium/en_US-hfc_male-medium lessac/medium/en_US-lessac-medium \
         danny/low/en_US-danny-low; do
  n=$(basename "$v")
  [ -f "$n.onnx" ] || { wget -q "$B/$v.onnx" -O "$n.onnx"; wget -q "$B/$v.onnx.json" -O "$n.onnx.json"; }
  echo "voice: $n"
done
cd ..

# espeak-ng without root: unpack the debs into a local tree; espeak.sh wraps it.
mkdir -p espeak && cd espeak
apt-get download espeak-ng espeak-ng-data libespeak-ng1
for d in *.deb; do dpkg-deb -x "$d" root; done
cd ..
./espeak.sh --version
