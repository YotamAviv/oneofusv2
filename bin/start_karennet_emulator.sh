#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONEOFUS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ONEOFUS_DIR"

echo "=== Starting karennet.net emulator (Firestore 8083, Functions 5004, UI 4003) ==="
nohup firebase --project=karennet --config=firebase_karennet.json emulators:start --only functions,firestore \
    > "$ONEOFUS_DIR/karennet_emulator.log" 2>&1 &

echo $! > "$ONEOFUS_DIR/.karennet_emulator.pid"
echo "Started. Log: $ONEOFUS_DIR/karennet_emulator.log"
echo "UI: http://localhost:4003"
echo "Stop with: (from nerdster) ./bin/stop_karennet_emulator.sh"

echo "Waiting for emulator to be ready..."
for i in $(seq 1 90); do
    if grep -q "All emulators ready" "$ONEOFUS_DIR/karennet_emulator.log" 2>/dev/null; then
        echo "Emulator ready! (${i}s)"
        break
    fi
    if [ "$i" -eq 90 ]; then
        echo "ERROR: Emulator did not become ready within 90s. Check $ONEOFUS_DIR/karennet_emulator.log"
        exit 1
    fi
    sleep 1
done
