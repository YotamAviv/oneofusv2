#!/usr/bin/env bash
# One take, start to finish. Steps 1-3 DELETE existing sign-in state so the app
# will prompt "Create Delegate Key?" again; step 4 records.
#
#   ./shoot.sh
#
# Prerequisites (see README.md): an Android emulator running, Chrome on it, a
# filmTools build of the identity app installed, and one-of-us.net approved as a
# link handler.
set -euo pipefail
cd "$(dirname "$0")"

SERIAL="${AVD:-emulator-5554}"
TOKEN=$(node -e "console.log(Object.values(require('./demo_identity.json').demoTokens)[0])")

echo "== 1/4  clearing published delegate statement =="
FIRST=$(curl -s "https://export.one-of-us.net/?spec=$TOKEN&includeId=true" | python3 -c "
import json,sys
v = sorted(list(json.load(sys.stdin).values())[0], key=lambda s: s['time'])
print(v[0].get('id',''))")
I_MEAN_IT=yes node truncate_statements.js --token "$TOKEN" --project oneofus --prod --keep "$FIRST" | tail -2

echo "== 2/4  clearing delegate key from the phone =="
adb -s "$SERIAL" shell am start -a android.intent.action.VIEW \
  -d "keymeid://deletekey?domain=nerdster.org" >/dev/null
sleep 5

echo "== 3/4  clearing keys stored in the browser =="
# Re-establish the forward each run: it goes stale whenever Chrome restarts, and
# the failure surfaces later as an unhelpful "socket hang up".
adb -s "$SERIAL" forward --remove-all >/dev/null 2>&1 || true
adb -s "$SERIAL" forward tcp:9222 localabstract:chrome_devtools_remote >/dev/null
until curl -s --max-time 3 http://localhost:9222/json/version >/dev/null; do sleep 1; done
node reset_browser.js | tail -1

echo "== 4/4  recording the take =="
TAKE=$(node shoot_signin.js | tail -2 | head -1 | tr -d ' ')
node overlay_taps.js "$TAKE" | tail -1
