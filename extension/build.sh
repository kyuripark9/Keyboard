#!/bin/bash
# Puts the browser extension together in one folder, with clack itself inside, so the side panel plays clack from the
# extension's own files rather than from the website:
#
#   bash extension/build.sh [out]        (default: extension/_build, the folder to pick with Load unpacked)
#
#   manifest.json, background.js, watch.js, panel.html, panel.js, icons/    the extension (this folder)
#   fonts/                   clack's fonts, so the panel asks Google for nothing
#   clack.html, clack.js     clack, the repo's index.html, its one script moved out to clack.js, as an extension page may
#                            only run scripts from the extension's own files, and its fonts from fonts/
#
# site/build.sh zips it for the website and store/pack.sh for the Chrome Web Store
set -euo pipefail
# [out] is from where you are, and it's emptied first, so it has to be new, empty or one this script built
case "${1:-}" in "") OUT=extension/_build ;; /*) OUT="$1" ;; *) OUT="$PWD/$1" ;; esac
cd "$(dirname "$0")/.."
if [ -e "$OUT" ] && [ ! -f "$OUT/clack.html" ] && [ -n "$(ls -A "$OUT")" ]; then
  echo "build: $OUT isn't a build of the extension, so it was left as it was; give a new folder" >&2
  exit 1
fi

# the Google Fonts stylesheet the fonts in fonts/ came from, on fonts.css's first line
FONTS="<link rel=\"stylesheet\" href=\"$(sed -n '1s|^/\* from \(https://fonts\.googleapis\.com/[^ ]*\)$|\1|p' extension/fonts/fonts.css)\">"
grep -qxF "$FONTS" index.html \
  || { echo "build: index.html asks Google Fonts for other fonts than extension/fonts/ has; fetch them again (see fonts.css)" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
for f in extension/*; do
  case "${f##*/}" in build.sh|_build) ;; *) cp -R "$f" "$OUT/" ;; esac
done

# clack without the artifact markers or Google Fonts, its script between a <script> line and a </script> line put in
# clack.js
grep -v -e '^<!--artifact:start-->$' -e '^<!--artifact:end-->$' index.html \
  | awk -v js="$OUT/clack.js" -v fonts="$FONTS" '
      /^<link rel="preconnect" href="https:\/\/fonts\.(googleapis|gstatic)\.com"/ { next }
      $0 == fonts { print "<link rel=\"stylesheet\" href=\"fonts/fonts.css\">"; next }
      n == 0 && /^<script>$/ { n = 1; print "<script src=\"clack.js\"></script>"; next }
      n == 1 && /^<\/script>$/ { n = 2; next }
      n == 1 { print > js; next }
      { print }
      END { if (n != 2) exit 1 }' > "$OUT/clack.html" \
  || { echo "build: index.html no longer has its script between a <script> line and a </script> line" >&2; exit 1; }
if grep -q -e 'fonts\.googleapis\.com' -e 'fonts\.gstatic\.com' "$OUT/clack.html" "$OUT/clack.js"; then
  echo "build: clack still asks Google Fonts for something" >&2
  exit 1
fi

echo "built $OUT"
