#!/usr/bin/env bash
# Join the finished takes into one file with a music bed, encoded the way
# YouTube wants it.
#
#   ./assemble.sh out/intro_<stamp>.mp4 soundtrack.mp3 CLIP CLIP ...
#
# Normally driven by `python3 sections.py --assemble intro`, which decides WHICH
# clips (the newest complete build of each section, in the storyboard's order)
# and names the output. This end owns the joining and the encoding only.
#
# No soundtrack, no problem: the video is built silent.
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
# No guessing. This used to pick the newest annotated take of a couple of kinds
# when given nothing, which was a way to build a video out of whatever happened
# to be lying about. Sections are chosen by `sections.py --assemble`, which knows
# the running order, takes the newest COMPLETE build of each, and refuses when
# one is missing rather than joining what it can.
if [ ${#CLIPS[@]} -eq 0 ]; then
  echo "no clips given." >&2
  echo "  Use: python3 sections.py --assemble intro" >&2
  echo "  This joins and encodes; it does not decide what goes in." >&2
  exit 1
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

TAIL=1.2           # seconds of music left running past the last frame

# STRAIGHT CUTS, no crossfade.
#
# This used to xfade 0.6s between every clip. The running order interleaves a
# title card before each section, so EVERY join touches a title -- and a title
# is only 1.0s long, so it spent more of its life dissolving than on screen.
# Three things were legible at once at a boundary: the outgoing section's
# closing card, the title, and the incoming section's first frame. A title is a
# caption, not a transition; it cuts.
#
# The clips are all 1080x2220, but concat refuses inputs that disagree on frame
# rate or aspect, and it fails deep inside ffmpeg when they do. Normalising each
# input first is cheap and makes that impossible.
TOTAL=0
for c in "${CLIPS[@]}"; do
  D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$c")
  TOTAL=$(python3 -c "print($TOTAL + $D)")
done
TOTAL=$(python3 -c "print(round($TOTAL, 3))")
echo "${#CLIPS[@]} clips, $TOTAL s"
for c in "${CLIPS[@]}"; do echo "  $c"; done

FILTER=""
INPUTS=()
LABELS=""
for i in "${!CLIPS[@]}"; do
  INPUTS+=(-i "${CLIPS[$i]}")
  FILTER="${FILTER}[$i:v]fps=25,format=yuv420p,setsar=1[c$i];"
  LABELS="${LABELS}[c$i]"
done
FILTER="${FILTER}${LABELS}concat=n=${#CLIPS[@]}:v=1:a=0[v]"

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
