#!/usr/bin/env bash
# Scene 1, from nothing to a finished file: the preamble, the vouch, and the two
# joined with the soundtrack if there is one.
#
#   ./build_scene1.sh
#
# Every take is recorded fresh, so this is also the check that the repository
# holds what the video needs. The one thing it cannot regenerate is
# footage/vouch_scan_2026-08-31.mp4 -- a real phone scanning a real identity card
# -- which is why that is tracked.
#
# IT WIPES THE APP. The vouch take needs a phone with no keys on it, so it runs
# `pm clear` and mints a new identity, which then vouches for Tom. The identity
# in demo_identity_private.json is NOT what ends up on the phone afterwards; put
# it back with the app's IMPORT screen if the sign-in and feed takes are next.
#
# Every trim below is derived from a take's own marks, not from a number that
# was true once. Each take opens with a sync flash and overlay_taps.js trims to
# it, but what is left is the flash page still sliding away -- so each piece
# starts at the first mark that names something worth seeing.
set -euo pipefail
cd "$(dirname "$0")"

STAMP=$(date +%Y%m%d-%H%M%S)
SOUND="${SOUND:-soundtrack.mp3}"

newest() { ls -t "$@" 2>/dev/null | head -1; }
# Seconds into the trimmed take where a mark lands, less a lead-in.
at() { node -e "
  const { loadMarks, TRIM_PAD } = require('./lib/marks');
  const m = loadMarks(process.argv[1]);
  const v = m[process.argv[2]];
  console.log(((typeof v === 'object' ? v.start : v) - TRIM_PAD - (+process.argv[3])).toFixed(2));
" "$1" "$2" "$3"; }

echo "== 1/6  the page, and a finger on the Play badge =="
node shoot_browser.js >/dev/null
BROWSER=$(newest out/browser_*.mp4 | grep -v taps || newest out/browser_*.mp4)
node overlay_taps.js "$BROWSER" >/dev/null 2>&1
BROWSER_T="${BROWSER%.mp4}_taps.mp4"

echo "== 2/6  the card =="
node card.js out/card_install.mp4 2.0 \
  "Use the app store links" "to install ONE-OF-US.NET" >/dev/null

echo "== 3/6  the home screen, and a finger on the app =="
node shoot_home.js >/dev/null
HOME=$(newest out/home_*.mp4 | grep -v taps || newest out/home_*.mp4)
node overlay_taps.js "$HOME" >/dev/null 2>&1
HOME_T="${HOME%.mp4}_taps.mp4"

echo "== 4/6  joining the preamble =="
SCENE0="out/scene0_preamble_${STAMP}.mp4"
ffmpeg -y -v error -ss "$(at "$BROWSER_T" page 0.7)" -i "$BROWSER_T" \
  -i out/card_install.mp4 \
  -ss "$(at "$HOME_T" home_screen 0.5)" -i "$HOME_T" \
  -filter_complex "[0:v]fps=25,setsar=1[a];[1:v]fps=25,setsar=1[b];[2:v]fps=25,setsar=1[c];\
[a][b][c]concat=n=3:v=1:a=0,format=yuv420p[v]" \
  -map "[v]" -c:v libx264 -crf 19 -preset medium "$SCENE0"

echo "== 5/6  the vouch (wipes the app) =="
node shoot_vouch.js >/dev/null
VOUCH=$(newest out/vouch_*.mp4 | grep -v taps || newest out/vouch_*.mp4)
node overlay_taps.js "$VOUCH" >/dev/null 2>&1
VOUCH_T="${VOUCH%.mp4}_taps.mp4"
HOLD=0.7 FADE=0.15 ./composite_scan.sh "$VOUCH_T" \
  footage/vouch_scan_2026-08-31.mp4 scanWindow out/_scene1_untrimmed.mp4 >/dev/null
# The preamble already showed the app opening; this scene starts on WELCOME.
SCENE1="out/scene1_vouch_${STAMP}.mp4"
ffmpeg -y -v error -ss "$(at "$VOUCH_T" welcome 0.6)" -i out/_scene1_untrimmed.mp4 \
  -c:v libx264 -crf 19 -preset medium -pix_fmt yuv420p "$SCENE1"
rm -f out/_scene1_untrimmed.mp4

echo "== 6/6  assembling =="
./assemble.sh "out/scene1_full_${STAMP}.mp4" "$SOUND" "$SCENE0" "$SCENE1" | tail -2

echo
echo "  $SCENE0"
echo "  $SCENE1"
echo "  out/scene1_full_${STAMP}.mp4"
