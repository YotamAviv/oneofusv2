#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Backend tests ==="
(cd functions && npm test)

echo "=== oneofusv22 integration tests (requires emulator on 8081/5002) ==="
flutter test integration_test/
