#!/bin/bash
# builds clack's menu bar app, clack.app, from clack-menubar.swift with the Swift compiler in Apple's Command Line Tools
#
#   bash menubar/build.sh                  -> menubar/build/clack.app
#   bash menubar/build.sh <app> [icon.png] -> that app, with a PNG of 512 px or more as its icon
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/build/clack.app}"
# it replaces what is there, so it only ever writes an app
case "$OUT" in *.app) ;; *) echo "build.sh: give a path ending in .app" >&2; exit 1 ;; esac
ICON="${2:-}"
# installed, the icon sits next to this script; in a clone of the repo, it is the bridge's
for f in "$HERE/icon-512.png" "$HERE/../bridge/icon-512.png"; do
  if [ -z "$ICON" ] && [ -f "$f" ]; then ICON="$f"; fi
done

xcrun --find swiftc >/dev/null 2>&1 || { echo "clack.app needs Apple's Command Line Tools: xcode-select --install" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
APP="$TMP/clack.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -suppress-warnings -target "$(uname -m)-apple-macos12" "$HERE/clack-menubar.swift" -o "$APP/Contents/MacOS/clack"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>ink.clack.menubar</string>
  <key>CFBundleName</key><string>clack</string>
  <key>CFBundleDisplayName</key><string>clack</string>
  <key>CFBundleExecutable</key><string>clack</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST

if [ -n "$ICON" ]; then
  mkdir "$TMP/AppIcon.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICON" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    if [ $s -lt 512 ]; then sips -z $((s * 2)) $((s * 2)) "$ICON" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null; fi
  done
  iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

mkdir -p "$(dirname "$OUT")"
rm -rf "$OUT"
mv "$APP" "$OUT"
echo "$OUT"
