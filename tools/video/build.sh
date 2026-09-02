#!/usr/bin/env bash
# Trim a raw recording to its action span and optionally burn in captions.
#
#   ./build.sh milhouse_identity-bar
#   ./build.sh milhouse_identity-bar captions/milhouse_identity_bar.ass
#
# Reads out/<name>.marks.json for the trim points, so the trim follows the take
# rather than being hand-timed.
set -euo pipefail

cd "$(dirname "$0")"
NAME="${1:?usage: build.sh <name> [captions.ass]}"
ASS="${2:-}"
LEAD="${LEAD:-0.5}"   # seconds of settled frame to keep before the first action

SRC="out/$NAME.webm"
MARKS="out/$NAME.marks.json"
[ -f "$SRC" ]   || { echo "missing $SRC (run record_nerdster.js first)" >&2; exit 1; }
[ -f "$MARKS" ] || { echo "missing $MARKS" >&2; exit 1; }

START=$(node -e "const m=require('./$MARKS');console.log(Math.max(0,m.start-$LEAD).toFixed(2))")
DUR=$(node   -e "const m=require('./$MARKS');console.log((m.end-m.start+$LEAD+0.5).toFixed(2))")

mkdir -p out
OUT="out/$NAME.mp4"
echo "trim: start=${START}s duration=${DUR}s -> $OUT"
ffmpeg -y -v error -ss "$START" -t "$DUR" -i "$SRC" -an \
  -c:v libx264 -crf 20 -preset slow -pix_fmt yuv420p -r 25 "$OUT"

if [ -n "$ASS" ]; then
  [ -d fonts ] || ./fetch_fonts.sh
  CAP="out/${NAME}_captions.mp4"
  echo "captions: $ASS -> $CAP"
  ffmpeg -y -v error -i "$OUT" -vf "subtitles=$ASS:fontsdir=fonts" \
    -c:v libx264 -crf 20 -preset slow -pix_fmt yuv420p "$CAP"
  echo "$CAP"
else
  echo "$OUT"
fi
