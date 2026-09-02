#!/usr/bin/env bash
# Put the demo phone's identity back on the emulator.
#
#   ./restore_demo_identity.sh
#
# The vouch take wipes the app to get a phone with no keys on it, which means it
# also destroys whatever identity was there. This puts the one in
# demo_identity_private.json back, so the takes that need a phone with a history
# -- sign-in, the Nerdster feed, the signature chain -- have one.
#
# Nothing else is hardcoded. The identity's token is computed from the key, and
# everything downstream of it -- the delegate, the statements -- is made by the
# app itself, running against production, the same as a real phone would.
#
# HOW IT GETS IN. Config.filmTools compiles in keymeid://importkey, which reads
# <app external files dir>/filmkey.json and imports it. That directory is
# adb-writable without root, which is the only reason this can be scripted at
# all: the identity key lives in secure storage and there is no other way in.
#
# Needs a filmTools build:
#   flutter build apk --debug --target-platform android-x64 --dart-define=filmTools=true
set -euo pipefail
cd "$(dirname "$0")"

SERIAL="${AVD:-emulator-5554}"
APP=net.oneofus.app
DIR="/sdcard/Android/data/$APP/files"

# The file the app reads must contain nothing but keys: importKeys parses every
# entry as a key pair, so the commentary in ours has to come out first.
TOKEN=$(python3 - <<'EOF'
import json, hashlib
src = json.load(open('demo_identity_private.json'))
keys = {k: v for k, v in src.items() if not k.startswith('_')}
json.dump(keys, open('/tmp/filmkey.json', 'w'))
pub = {k: v for k, v in keys['one-of-us.net'].items() if k != 'd'}
print(hashlib.sha1(json.dumps(dict(sorted(pub.items())), indent=2).encode()).hexdigest())
EOF
)
EXPECT=$(python3 -c "import json;print(json.load(open('demo_identity.json'))['demoTokens']['demo-phone'])")
[ "$TOKEN" = "$EXPECT" ] || {
  echo "the private key is not the identity demo_identity.json names:" >&2
  echo "  key file: $TOKEN" >&2
  echo "  allowlist: $EXPECT" >&2
  exit 1
}
echo "identity $TOKEN"

# The app has to have run once for its files directory to exist.
adb -s "$SERIAL" shell "mkdir -p $DIR" >/dev/null 2>&1 || true
adb -s "$SERIAL" push /tmp/filmkey.json "$DIR/filmkey.json" >/dev/null
rm -f /tmp/filmkey.json

# Watch the app say it worked. The deep link is silent on failure -- a build
# without filmTools ignores it entirely -- so the log line is the only evidence
# that anything happened.
adb -s "$SERIAL" logcat -c
adb -s "$SERIAL" shell am start -a android.intent.action.VIEW -d "keymeid://importkey" >/dev/null
for _ in $(seq 1 20); do
  if adb -s "$SERIAL" logcat -d | grep -q "IMPORTKEY: imported keys"; then
    echo "imported"
    # Off the device: it is a private key, and it does not need to stay there.
    adb -s "$SERIAL" shell "rm -f $DIR/filmkey.json"
    exit 0
  fi
  sleep 0.5
done

echo "no IMPORTKEY line in the log after 10s." >&2
adb -s "$SERIAL" logcat -d | grep -i "importkey" >&2 || true
echo "Is this a filmTools build? Without it keymeid://importkey is compiled out." >&2
adb -s "$SERIAL" shell "rm -f $DIR/filmkey.json"
exit 1
