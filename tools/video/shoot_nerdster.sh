#!/usr/bin/env bash
# One take of the Nerdster feed basics: filter to books, sort by comments, swipe
# to snooze, swipe to dismiss, react. Step 1 DELETES what the last take
# published so the feed starts the same way; step 3 records.
#
#   ./shoot_nerdster.sh
#
# Requires sign-in state that ./shoot.sh leaves behind -- the vouch and the
# delegate key. This script deliberately does NOT touch either: it clears
# nerdster.org statements only, so reshooting this costs one command and does
# not cost a reshoot of the sign-in take.
#
# Ends with the annotation pass, so one command gets from nothing to the
# finished video. To re-annotate without reshooting -- after changing the copy,
# or the bubble and prompter styling -- run just that step against a take that
# already exists:
#
#   node annotate.js cues/nerdster.json out/nerdster_<stamp>_taps.mp4
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-}"   # where the finished section goes, if the caller wants it somewhere

SERIAL="${AVD:-emulator-5554}"
TOKEN=$(node -e "console.log(Object.values(require('./demo_identity.json').demoTokens)[0])")

echo "== 1/4  clearing what the last take published to nerdster.org =="
# Named by who delegated it, not by its own token: the delegate key is minted
# fresh every time sign-in is reshot, so nothing can hardcode it.
I_MEAN_IT=yes node truncate_statements.js \
  --delegate-of "$TOKEN" --domain nerdster.org --project nerdster --prod --all | tail -2

echo "== 2/4  connecting to Chrome on the device =="
# Re-establish the forward each run: it goes stale whenever Chrome restarts, and
# the failure surfaces later as an unhelpful "socket hang up".
adb -s "$SERIAL" forward --remove-all >/dev/null 2>&1 || true
adb -s "$SERIAL" forward tcp:9222 localabstract:chrome_devtools_remote >/dev/null
until curl -s --max-time 3 http://localhost:9222/json/version >/dev/null; do sleep 1; done

echo "== 3/4  recording the take =="
TAKE=$(node shoot_nerdster.js | tail -2 | head -1 | tr -d ' ')
TAPS=$(node overlay_taps.js "$TAKE" | tail -1 | cut -d' ' -f1)

echo "== 4/4  prompter, bubbles and zooms =="
ANNOTATED=$(node annotate.js cues/nerdster.json "$TAPS" | tail -1 | cut -d' ' -f2)

# An output path means sections.py --build can drive this the same as any other
# section. Without one the caller has to go hunting for whatever was written
# last, which is how a build ends up made of a stale take.
if [ -n "${OUT:-}" ]; then
  cp "$ANNOTATED" "$OUT"
  echo "$OUT"
fi
