#!/bin/bash
cd "$(dirname "$0")/.."

FAILED_TESTS=()
PASSED_TESTS=()

# Prerequisites: oneofus emulator on 8081/5002
echo "Checking prerequisites..."
curl -s --max-time 3 http://localhost:8081/ > /dev/null \
    || { echo "ERROR: OneOfUs Firebase emulator not responding on port 8081."; exit 1; }
curl -s --max-time 3 http://localhost:5002/ > /dev/null \
    || { echo "ERROR: OneOfUs Functions emulator not responding on port 5002."; exit 1; }
echo "Prerequisites OK."
echo ""

echo "=== Backend tests ==="
if (cd functions && npm test); then
    PASSED_TESTS+=("Backend tests")
else
    FAILED_TESTS+=("Backend tests")
fi
echo ""

ANDROID_DEVICE=$(flutter devices 2>/dev/null | grep '(emulator)' | awk -F'•' '{print $2}' | tr -d ' ' | head -1)
if [ -n "$ANDROID_DEVICE" ]; then
    echo "=== Running Integration Tests (Android emulator: $ANDROID_DEVICE) ==="
    if flutter test integration_test/ -d "$ANDROID_DEVICE"; then
        PASSED_TESTS+=("Integration tests (android)")
    else
        FAILED_TESTS+=("Integration tests (android)")
    fi
else
    echo "=== No Android emulator running — skipping integration tests ==="
    echo "    (Start one with: flutter emulators --launch Pixel_3a_API_35)"
fi
echo ""

echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo "PASSED (${#PASSED_TESTS[@]}):"
for test in "${PASSED_TESTS[@]}"; do echo "  ✅ $test"; done
echo ""
echo "FAILED (${#FAILED_TESTS[@]}):"
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo "  (none)"
else
    for test in "${FAILED_TESTS[@]}"; do echo "  ❌ $test"; done
fi
echo "========================================"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then exit 1; fi
