#!/bin/bash
# Puts the browser extension together in one folder, with clack itself inside, so the side panel plays clack from the
# extension's own files rather than from the website:
#
#   bash extension/build.sh [out]        (default: extension/_build, the folder to pick with Load unpacked)
#
#   manifest.json, background.js, watch.js, panel.html, panel.js, icons/    the extension (this folder)
#   clack.html, clack.js     clack, the repo's index.html, its one script moved out to clack.js, as an extension page may
#                            only run scripts from the extension's own files
#
# site/build.sh zips it for the website and store/pack.sh for the Chrome Web Store
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-extension/_build}"

rm -rf "$OUT"
mkdir -p "$OUT"
for f in extension/*; do
  case "${f##*/}" in build.sh|_build) ;; *) cp -R "$f" "$OUT/" ;; esac
done

# clack without the artifact markers, its script between a <script> line and a </script> line put in clack.js
grep -v -e '^<!--artifact:start-->$' -e '^<!--artifact:end-->$' index.html \
  | awk -v js="$OUT/clack.js" '
      n == 0 && /^<script>$/ { n = 1; print "<script src=\"clack.js\"></script>"; next }
      n == 1 && /^<\/script>$/ { n = 2; next }
      n == 1 { print > js; next }
      { print }
      END { if (n != 2) exit 1 }' > "$OUT/clack.html" \
  || { echo "build: index.html no longer has its script between a <script> line and a </script> line" >&2; exit 1; }

echo "built $OUT"
