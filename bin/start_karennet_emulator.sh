#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONEOFUS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ONEOFUS_DIR"

EXPORT=false
EMPTY=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --export) EXPORT=true ;;
        --empty) EMPTY=true ;;
    esac
    shift
done

if [ "$EXPORT" = true ]; then
    NOW=$(date +%y-%m-%d--%H-%M)
    echo "=== Exporting karennet-e4291 from production ==="
    mkdir -p exports
    gcloud config set project karennet-e4291
    gcloud firestore export gs://karennet-e4291/karennet-$NOW
    gsutil -m cp -r gs://karennet-e4291/karennet-$NOW exports/
    IMPORT="exports/karennet-$NOW"
elif [ "$EMPTY" = true ]; then
    IMPORT=""
else
    IMPORT=$(ls -td exports/karennet-* 2>/dev/null | head -1 || true)
fi

echo "=== Starting karennet.net emulator (Firestore 8083, Functions 5004, UI 4003) ==="
if [ -n "${IMPORT:-}" ]; then
    echo "Using import: $IMPORT"
    nohup firebase --project=karennet --config=firebase_karennet.json emulators:start --only functions,firestore --import "$IMPORT/" \
        > "$ONEOFUS_DIR/karennet_emulator.log" 2>&1 &
else
    echo "No import data found. Starting with empty data."
    nohup firebase --project=karennet --config=firebase_karennet.json emulators:start --only functions,firestore \
        > "$ONEOFUS_DIR/karennet_emulator.log" 2>&1 &
fi

echo $! > "$ONEOFUS_DIR/.karennet_emulator.pid"
echo "Started. Log: $ONEOFUS_DIR/karennet_emulator.log"
echo "UI: http://localhost:4003"
echo "Stop with: ./bin/stop_karennet_emulator.sh"

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
