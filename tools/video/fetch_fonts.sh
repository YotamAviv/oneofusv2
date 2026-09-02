#!/usr/bin/env bash
# Comic Neue — the face index.html already loads for the comic bands, reused
# for the in-character caption style. Not vendored; fetched on demand.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p fonts
[ -f fonts/ComicNeue-Bold.ttf ] && { echo "fonts/ComicNeue-Bold.ttf present"; exit 0; }

CSS=$(wget -qO- -U "Mozilla/5.0 (X11; Linux x86_64)" \
  "https://fonts.googleapis.com/css2?family=Comic+Neue:wght@700&display=swap")
URL=$(printf '%s' "$CSS" | grep -oE "https://fonts.gstatic.com/[^)]*" | head -1)
[ -n "$URL" ] || { echo "could not resolve Comic Neue url" >&2; exit 1; }

wget -q "$URL" -O fonts/ComicNeue-Bold.ttf
fc-query -f "%{family} %{style}\n" fonts/ComicNeue-Bold.ttf
