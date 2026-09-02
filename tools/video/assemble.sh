#!/usr/bin/env bash
# Join the finished takes into one file with a music bed, encoded the way
# YouTube wants it.
#
#   ./assemble.sh out/upload.mp4 soundtrack.mp3 out/a_annotated.mp4 out/b_annotated.mp4
#
# With no arguments it uses soundtrack.mp3 and the newest annotated take of each
# kind, which is what a review pass wants. No soundtrack, no problem: the video
# is built silent.
#
# PROTOTYPE. The soundtrack is optional and never committed -- see soundtrack.json
# for which track this was built against and where it came from.
#
# The takes are 1080x2220 -- the emulator's screen, taller than 9:16. Kept as
# shot, because fitting it to 9:16 means scaling down until there are pillars
# down both sides, and the whole problem with this material is that the text is
# small already. YouTube accepts it and letterboxes.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-out/upload.mp4}"
SOUND="${2:-soundtrack.mp3}"
# Shift one at a time. `shift 2` with fewer than two arguments shifts nothing,
# which quietly left the OUTPUT filename sitting in the clip list.
if [ $# -gt 0 ]; then shift; fi
if [ $# -gt 0 ]; then shift; fi
CLIPS=("$@")
if [ ${#CLIPS[@]} -eq 0 ]; then
  CLIPS=(
    "$(ls -t out/nerdster_*_taps_annotated.mp4 | head -1)"
    "$(ls -t out/crypto_*_taps_annotated.mp4 | head -1)"
  )
fi
# The soundtrack is optional and not in the repository -- the licence on a stock
# track covers using it in a project, not redistributing the file, and this
# repository is public. Drop one in as soundtrack.mp3 and it gets used; leave it
# out and the video is built silent rather than not built at all. See
# soundtrack.json for what the reference track is and where it came from.
if [ -f "$SOUND" ]; then
  echo "soundtrack: $SOUND"
else
  echo "no soundtrack at $SOUND -- building silent (see soundtrack.json)"
  SOUND=""
fi

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

AUDIO=()
LENGTH=$TOTAL
if [ -n "$SOUND" ]; then
  # Only run past the last frame when there is music to carry it.
  LENGTH=$(python3 -c "print(round($TOTAL + $TAIL, 3))")
  FADEOUT=$(python3 -c "print(round($LENGTH - 1.6, 3))")
  AUDIO=(-i "$SOUND"
         -map "${#CLIPS[@]}:a"
         -af "afade=t=in:st=0:d=0.8,afade=t=out:st=$FADEOUT:d=1.6"
         -c:a aac -b:a 192k -ar 48000 -ac 2)
fi

ffmpeg -y -v error "${INPUTS[@]}" "${AUDIO[@]}" \
  -filter_complex "$FILTER" \
  -map "[v]" \
  -t "$LENGTH" \
  -c:v libx264 -profile:v high -crf 19 -preset slow -pix_fmt yuv420p -r 25 \
  -movflags +faststart "$OUT"

echo
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,channels \
  -show_entries format=duration,size -of default=nw=1 "$OUT"
echo "-> $OUT"
