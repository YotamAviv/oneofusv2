#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploying to Firebase Hosting ==="
firebase deploy --only hosting --project=one-of-us-net

echo ""
echo "=== Done ==="
echo "Home: https://one-of-us.net"
