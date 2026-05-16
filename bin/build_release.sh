#!/usr/bin/env bash
set -euo pipefail

# Derive build number from git commit count — never needs manual bumping.
build=$(git rev-list --count HEAD)

# Verify version
echo "=== Version ==="
version=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
echo "$version+$build"

# Verify prod FireChoice (abort if not prod)
echo ""
echo "=== FireChoice ==="
line=$(grep "final.*_fireChoice" lib/core/config.dart)
echo "$line"
if ! echo "$line" | grep -q "FireChoice.prod"; then
  echo "ERROR: FireChoice is not set to prod! Aborting." >&2
  exit 1
fi

if [ -d "builds/$build" ]; then
  echo "ERROR: builds/$build already exists. Did you forget to commit your changes?" >&2
  exit 1
fi

echo ""
echo "=== Building appbundle (build $build) ==="
flutter build appbundle --build-number="$build"

echo ""
echo "=== Saving to builds/$build ==="
mkdir -p "builds/$build"
cp build/app/outputs/bundle/release/app-release.aab "builds/$build/"
echo "Saved: builds/$build/app-release.aab"

echo ""
echo "=== Tagging release ==="
git tag "v$version+$build"
git push origin "v$version+$build"
echo "Tagged and pushed: v$version+$build"
