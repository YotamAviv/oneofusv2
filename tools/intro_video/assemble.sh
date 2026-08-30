#!/usr/bin/env bash
# Join the finished takes into one file with a music bed, encoded the way
# YouTube wants it.
#
#   ./assemble.sh out/upload.mp4 out/music.m4a out/a_annotated.mp4 out/b_annotated.mp4
#
# With no arguments it uses out/music.m4a and the newest annotated take of each
# kind, which is what a review pass wants.
#
# PROTOTYPE, and the music is the part to think about before anything is
# published: this is a stock track lifted off YouTube, so whether it can be
# used, and whether Content ID says so, is a question for whoever uploads it.
# out/ is gitignored, so no audio file lands in the repo.
#
# The takes are 1080x2220 -- the emulator's screen, taller than 9:16. Kept as
# shot, because fitting it to 9:16 means scaling down until there are pillars
# down both sides, and the whole problem with this material is that the text is
# small already. YouTube accepts it and letterboxes.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-out/upload.mp4}"
MUSIC="${2:-out/music.m4a}"
shift 2 2>/dev/null || true
CLIPS=("$@")
if [ ${#CLIPS[@]} -eq 0 ]; then
  CLIPS=(
    "$(ls -t out/nerdster_*_taps_annotated.mp4 | head -1)"
    "$(ls -t out/crypto_*_taps_annotated.mp4 | head -1)"
  )
fi
[ -f "$MUSIC" ] || { echo "no music at $MUSIC"; exit 1; }

XFADE=0.6          # seconds of crossfade between takes
TAIL=1.2           # seconds of music left running past the last frame

# Total, allowing for what each crossfade eats.
TOTAL=0
for c in "${CLIPS[@]}"; do
  D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$c")
  TOTAL=$(python3 -c "print($TOTAL + $D)")
done
TOTAL=$(python3 -c "print(round($TOTAL - $XFADE * (${#CLIPS[@]} - 1), 3))")
echo "${#CLIPS[@]} clips, $TOTAL s"
for c in "${CLIPS[@]}"; do echo "  $c"; done

# Crossfade the clips together. xfade wants each input's offset in the OUTPUT
# timeline, which is where the running total minus the fades already spent goes.
FILTER=""
INPUTS=()
PREV="[0:v]"
ACC=0
for i in "${!CLIPS[@]}"; do
  INPUTS+=(-i "${CLIPS[$i]}")
  D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${CLIPS[$i]}")
  if [ "$i" -eq 0 ]; then
    ACC=$(python3 -c "print(round($D - $XFADE, 3))")
    continue
  fi
  NEXT="[x$i]"
  FILTER="${FILTER}${PREV}[$i:v]xfade=transition=fade:duration=$XFADE:offset=$ACC${NEXT};"
  PREV="$NEXT"
  ACC=$(python3 -c "print(round($ACC + $D - $XFADE, 3))")
done
FILTER="${FILTER}${PREV}format=yuv420p[v]"

FADEOUT=$(python3 -c "print(round($TOTAL + $TAIL - 1.6, 3))")
ffmpeg -y -v error "${INPUTS[@]}" -i "$MUSIC" \
  -filter_complex "$FILTER" \
  -map "[v]" -map "${#CLIPS[@]}:a" \
  -af "afade=t=in:st=0:d=0.8,afade=t=out:st=$FADEOUT:d=1.6" \
  -t "$(python3 -c "print(round($TOTAL + $TAIL, 3))")" \
  -c:v libx264 -profile:v high -crf 19 -preset slow -pix_fmt yuv420p -r 25 \
  -c:a aac -b:a 192k -ar 48000 -ac 2 \
  -movflags +faststart "$OUT"

echo
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,channels \
  -show_entries format=duration,size -of default=nw=1 "$OUT"
echo "-> $OUT"
