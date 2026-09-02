#!/usr/bin/env bash
# One take of the signature chain, from nothing to the finished video: record,
# add the touch indicators, then the prompter, bubbles and zooms.
#
#   ./shoot_crypto.sh
#
# There is no reset step. The sequence only reads and verifies what other people
# signed, so it publishes nothing and can be re-run at will.
#
# To re-annotate without reshooting -- after changing the copy, or the bubble and
# prompter styling -- run just that step against a take that already exists:
#
#   node annotate.js cues/crypto_chain.json out/crypto/<stamp>/crypto_taps.mp4
set -euo pipefail
cd "$(dirname "$0")"

# One stamped directory holds the take, its intermediates and the finished
# section. sections.py sets BUILD_DIR; run by hand, this names its own.
BUILD_DIR="${BUILD_DIR:-out/crypto/$(date +%Y%m%d-%H%M%S)}"
export BUILD_DIR
mkdir -p "$BUILD_DIR"

OUT="${1:-}"   # where the finished section goes, if the caller wants it somewhere

SERIAL="${AVD:-emulator-5554}"

echo "== 1/3  connecting to Chrome on the device =="
# Re-establish the forward each run: it goes stale whenever Chrome restarts, and
# the failure surfaces later as an unhelpful "socket hang up".
adb -s "$SERIAL" forward --remove-all >/dev/null 2>&1 || true
adb -s "$SERIAL" forward tcp:9222 localabstract:chrome_devtools_remote >/dev/null
until curl -s --max-time 3 http://localhost:9222/json/version >/dev/null; do sleep 1; done

echo "== 2/3  recording the take =="
TAKE=$(node shoot_crypto.js | tail -2 | head -1 | tr -d ' ')
TAPS=$(node overlay_taps.js "$TAKE" | tail -1 | cut -d' ' -f1)

echo "== 3/3  prompter, bubbles and zooms =="
ANNOTATED=$(node annotate.js cues/crypto_chain.json "$TAPS" | tail -1 | cut -d' ' -f2)

# An output path means sections.py --build can drive this the same as any other
# section. Without one the caller has to go hunting for whatever was written
# last, which is how a build ends up made of a stale take.
if [ -n "${OUT:-}" ]; then
  cp "$ANNOTATED" "$OUT"
  echo "$OUT"
fi
