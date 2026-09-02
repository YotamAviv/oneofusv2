#!/usr/bin/env bash
# One take, start to finish: the Nerdster's home page in a browser, into the web
# app, out to the identity app to authorise a delegate key, and back signed in.
# Steps 1-3 DELETE existing sign-in state so the app will prompt "Create Delegate
# Key?" again; step 4 records; step 5 annotates and trims.
#
#   ./shoot_signin.sh
#
# It was called shoot.sh, from when it was the only one. The name said nothing
# about which take it shot, and every other take names itself.
#
# Ends with the annotation pass, so one command gets from nothing to the finished
# section. To re-annotate without reshooting -- which matters more here than
# anywhere else, because reshooting costs the delegate key and a round of
# publishing -- run just that step against a take that already exists:
#
#   node annotate.js cues/signin.json out/signin_<stamp>_taps.mp4
#
# Prerequisites (see README.md): an Android emulator running, Chrome on it, a
# filmTools build of the identity app installed, and one-of-us.net approved as a
# link handler.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-}"   # where the finished section goes, if the caller wants it somewhere

SERIAL="${AVD:-emulator-5554}"
TOKEN=$(node -e "console.log(Object.values(require('./demo_identity.json').demoTokens)[0])")

echo "== 1/5  clearing published delegate statement =="
FIRST=$(curl -s "https://export.one-of-us.net/?spec=$TOKEN&includeId=true" | python3 -c "
import json,sys
v = sorted(list(json.load(sys.stdin).values())[0], key=lambda s: s['time'])
print(v[0].get('id',''))")
I_MEAN_IT=yes node truncate_statements.js --token "$TOKEN" --project oneofus --prod --keep "$FIRST" | tail -2

echo "== 2/5  clearing delegate key from the phone =="
adb -s "$SERIAL" shell am start -a android.intent.action.VIEW \
  -d "keymeid://deletekey?domain=nerdster.org" >/dev/null
sleep 5

echo "== 3/5  clearing keys stored in the browser =="
# Re-establish the forward each run: it goes stale whenever Chrome restarts, and
# the failure surfaces later as an unhelpful "socket hang up".
adb -s "$SERIAL" forward --remove-all >/dev/null 2>&1 || true
adb -s "$SERIAL" forward tcp:9222 localabstract:chrome_devtools_remote >/dev/null
until curl -s --max-time 3 http://localhost:9222/json/version >/dev/null; do sleep 1; done
node reset_browser.js | tail -1

echo "== 4/5  recording the take =="
TAKE=$(node shoot_signin.js | tail -2 | head -1 | tr -d ' ')
TAPS=$(node overlay_taps.js "$TAKE" | tail -1 | cut -d' ' -f1)

echo "== 5/5  prompter =="
ANNOTATED=$(node annotate.js cues/signin.json "$TAPS" | tail -1 | cut -d' ' -f2)

# Trimmed to `home`: the take opens on a launch and a sync flash that are staging
# rather than content, and the section starts when the home page is on screen.
AT=$(node -e "
  const {loadMarks, timeOf} = require('./lib/marks');
  console.log(timeOf({at: 'home'}, loadMarks('$TAPS'), 'trim'));
")
echo "  trim to home at ${AT}s"

# An output path means sections.py --build can drive this the same as any other
# section. Without one the caller has to go hunting for whatever was written
# last, which is how a build ends up made of a stale take.
if [ -n "${OUT:-}" ]; then
  ffmpeg -y -v error -ss "$AT" -i "$ANNOTATED" -c:v libx264 -crf 19 -preset medium \
    -pix_fmt yuv420p "$OUT"
  echo "$OUT"
fi
