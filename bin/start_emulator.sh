#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

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
    echo "=== Exporting one-of-us-net from production ==="
    mkdir -p exports
    gcloud config set project one-of-us-net
    gcloud firestore export gs://one-of-us-net/oneofus-$NOW
    gsutil -m cp -r gs://one-of-us-net/oneofus-$NOW exports/
    IMPORT="exports/oneofus-$NOW"
elif [ "$EMPTY" = true ]; then
    IMPORT=""
else
    IMPORT=$(ls -td exports/oneofus-* 2>/dev/null | head -1 || true)
fi

echo "=== Starting one-of-us-net emulator (Firestore 8081, Functions 5002, UI 4001) ==="
if [ -n "${IMPORT:-}" ]; then
    echo "Using import: $IMPORT"
    nohup firebase --project=one-of-us-net --config=firebase_emulator.json emulators:start --only functions,firestore --import "$IMPORT/" \
        > "$REPO_DIR/oneofus_emulator.log" 2>&1 &
else
    echo "No import data found. Starting with empty data."
    nohup firebase --project=one-of-us-net --config=firebase_emulator.json emulators:start --only functions,firestore \
        > "$REPO_DIR/oneofus_emulator.log" 2>&1 &
fi

echo $! > "$REPO_DIR/.oneofus_emulator.pid"
echo "Started. Log: oneofus_emulator.log"
echo "UI: http://localhost:4001"
echo "Stop with: ./bin/stop_emulator.sh"
