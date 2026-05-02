#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

PIDFILE="$REPO_DIR/.oneofus_emulator.pid"
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping one-of-us-net emulator (PID $PID)..."
        # Kill the process group to catch child java/node processes
        kill -- -$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ') 2>/dev/null || kill "$PID"
        sleep 2
    fi
    rm "$PIDFILE"
else
    echo "No PID file found. Is the emulator running?"
fi

# Kill any stale processes holding emulator ports
for PORT in 5002 8081 9151; do
    PID=$(lsof -ti :"$PORT" 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "Killing stale process on port $PORT (PID $PID)..."
        kill "$PID" 2>/dev/null
    fi
done
