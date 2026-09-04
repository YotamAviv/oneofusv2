#!/usr/bin/env bash
# Save and restore the phone's keyring, so a destructive take can be run again.
#
#   ./app_state.sh save    out/close_account.keys.json
#   ./app_state.sh restore out/close_account.keys.json
#
# THE OTHER HALF OF THE REWIND. `close_account` changes two things:
#
#   the network -- one appended `clear` statement. snapshot_statements.js records
#     the head before and truncate_statements.js --keep rewinds to it after.
#     Exact, because the statement streams are append-only hash chains.
#   the phone -- the delegate's PRIVATE KEY, deleted from the local keyring.
#     Clearing a delegation whose key this phone holds also deletes that key; it
#     is a separate act and a permanent one.
#
# This covers the phone. Together they make the take repeatable.
#
# WHY IT MATTERS THAT IT IS THE SAME KEY. Reshooting sign-in also ends with a
# delegate, but a DIFFERENT one, and the ratings in `nerdster` and
# `crypto_teaser` were signed by the old one -- they end up orphaned and vanish
# from the feed. Re-importing brings back the same key with the same token, so
# they stay its own. That cost a reshoot of sign-in AND of nerdster every time.
#
# HOW. Two filming-only deep links in the identity app, compiled out of any
# shipped build (Config.filmTools):
#
#   keymeid://exportkey   writes the keyring to the app's external files dir
#   keymeid://importkey   reads it back
#
# Both use <app external files dir>/filmkey.json, which adb can read and write
# with no storage permission and without root. The keys go through a file, never
# through a URL, a log, or shell history. The format is the same JSON the app's
# own IMPORT / EXPORT screen produces and accepts.
#
# NEEDS A filmTools BUILD:
#   flutter build apk --debug --target-platform android-x64 --dart-define=filmTools=true
#
# THIS REPLACED a tar of /data/data via run-as. That worked, but it dragged in
# 86MB of Flutter engine cache and assets -- restoring a stale kernel_blob over a
# rebuilt app is its own kind of broken -- and it restored Keystore-encrypted
# ciphertext, which stops decrypting if the app is ever reinstalled. This is a
# few KB of the app's own format and survives a reinstall.
#
# ORDER. Restore the phone first and the network last; the app reads the network
# on its next launch.
set -euo pipefail
cd "$(dirname "$0")"

APP="${APP:-net.oneofus.app}"
SERIAL="${AVD:-emulator-5554}"
REMOTE="/sdcard/Android/data/$APP/files/filmkey.json"
MODE="${1:-}"
FILE="${2:-}"

if [ -z "$MODE" ] || [ -z "$FILE" ]; then
  echo "usage: ./app_state.sh save|restore <keys.json>" >&2
  exit 1
fi

# The deep link is handled by a running app, and handled once. Bring it up and
# let it settle before firing, or the intent lands on a splash screen that has
# not wired up its link handler yet and nothing happens -- silently.
wake() {
  adb -s "$SERIAL" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 9
}
deeplink() {
  adb -s "$SERIAL" shell am start -a android.intent.action.VIEW -d "$1" >/dev/null
  sleep 3
}

case "$MODE" in
  save)
    mkdir -p "$(dirname "$FILE")"
    adb -s "$SERIAL" shell rm -f "$REMOTE" 2>/dev/null || true
    wake
    deeplink "keymeid://exportkey"
    if ! adb -s "$SERIAL" shell test -f "$REMOTE"; then
      echo "exportkey wrote nothing. Is this a filmTools build?" >&2
      echo "  flutter build apk --debug --dart-define=filmTools=true" >&2
      exit 1
    fi
    adb -s "$SERIAL" pull "$REMOTE" "$FILE" >/dev/null
    adb -s "$SERIAL" shell rm -f "$REMOTE"
    # Say what came back. An export missing the delegate is the failure that
    # matters here, and it looks exactly like a successful one on disk.
    echo "saved $(python3 -c "import json;print(', '.join(json.load(open('$FILE'))))" \
      2>/dev/null || echo '?') -> $FILE"
    ;;
  restore)
    [ -s "$FILE" ] || { echo "$FILE is missing or empty" >&2; exit 1; }
    adb -s "$SERIAL" push "$FILE" "$REMOTE" >/dev/null
    wake
    deeplink "keymeid://importkey"
    adb -s "$SERIAL" shell rm -f "$REMOTE"
    # STOP THE APP AFTERWARDS. importKeys replaces the keyring under a running
    # app, which then carries on with whatever it read at launch -- including its
    # view of the statement chain, which a restore has usually just rewound.
    # Leaving it running is how sign-in came to create a delegate key locally and
    # publish no delegate statement for it: the app was writing against a head
    # that no longer existed. The next launch reads both fresh.
    adb -s "$SERIAL" shell am force-stop "$APP"
    echo "restored keyring from $FILE (app stopped; it reads this on next launch)"
    ;;
  *)
    echo "usage: ./app_state.sh save|restore <keys.json>" >&2
    exit 1
    ;;
esac
