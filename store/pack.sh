#!/bin/bash
# Zips the browser extension, with clack inside (extension/build.sh), for the Chrome Web Store and Edge Add-ons, which
# want manifest.json at the top of the zip rather than in a folder like the website's clack-extension.zip:
#
#   bash store/pack.sh        ->  store/clack-extension-<version>.zip
#
# Each upload needs a higher "version" in extension/manifest.json than the last one
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(python3 -c 'import json; print(json.load(open("extension/manifest.json"))["version"])')"
ZIP="$PWD/store/clack-extension-$VERSION.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
bash extension/build.sh "$TMP/ext" >/dev/null
rm -f "$ZIP"
(cd "$TMP/ext" && zip -qrX "$ZIP" . -x '*.DS_Store')
echo "built store/clack-extension-$VERSION.zip"
