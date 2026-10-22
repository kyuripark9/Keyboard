#!/bin/bash
# Builds the clack website into one folder, ready for GitHub Pages:
#
#   bash site/build.sh [out]        (default: site/_site)
#
#   index.html, img/         the landing page (site/)
#   play/                    clack itself, the repo's index.html, installable as its own app
#   clack-extension.zip      the browser extension (extension/), unzipping to a clack-extension folder
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-site/_site}"

rm -rf "$OUT"
mkdir -p "$OUT/play"
cp site/index.html "$OUT/"
cp -R site/img "$OUT/"
cp bridge/favicon-32.png bridge/apple-touch-icon.png bridge/icon-192.png bridge/icon-512.png "$OUT/"

# clack without the artifact markers, with the manifest and icons the bridge gives it on localhost, so Chrome, Edge or
# Safari can keep the web version as an app too
TAGS='<link rel="manifest" href="manifest.webmanifest"><link rel="icon" href="../favicon-32.png" sizes="32x32"><link rel="apple-touch-icon" href="../apple-touch-icon.png"><meta name="theme-color" content="#2c62fb"><meta name="apple-mobile-web-app-title" content="clack">'
grep -v -e '^<!--artifact:start-->$' -e '^<!--artifact:end-->$' index.html \
  | awk -v tags="$TAGS" '{ print } !done && /^<meta charset=/ { print tags; done = 1 }' > "$OUT/play/index.html"
grep -q 'manifest.webmanifest' "$OUT/play/index.html" || { echo "build: no <meta charset> line in index.html" >&2; exit 1; }
cat > "$OUT/play/manifest.webmanifest" <<'EOF'
{
  "name": "clack", "short_name": "clack", "id": "./", "start_url": "./", "scope": "./", "display": "standalone",
  "background_color": "#f4f5f7", "theme_color": "#2c62fb",
  "description": "Ten materials to press while your agent works. clack lets go of you when it is done.",
  "icons": [
    { "src": "../icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "../icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
EOF

# the extension, zipped from a folder named the way the site's steps call it
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R extension "$TMP/clack-extension"
ZIP="$(cd "$OUT" && pwd)/clack-extension.zip"
(cd "$TMP" && zip -qrX "$ZIP" clack-extension -x '*.DS_Store')

echo "built $OUT"
