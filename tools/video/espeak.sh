#!/usr/bin/env bash
D="$(cd "$(dirname "$0")" && pwd)/espeak/root"
LD_LIBRARY_PATH="$D/usr/lib/x86_64-linux-gnu" \
  "$D/usr/bin/espeak-ng" --path="$D/usr/share/espeak-ng-data" "$@"
