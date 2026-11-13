#!/bin/bash
# Builds NerdrKeys.app and installs it to ~/Applications. Re-run after editing main.swift.
set -euo pipefail
cd "$(dirname "$0")"

NAME="NerdrKeys"
APP="$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"

swiftc -O -o "$APP/Contents/MacOS/$NAME" main.swift

# Bundle the font so the app looks the same on any Mac (SIL OFL: license ships with it).
cp Fonts/*.otf Fonts/OFL-LICENSE.txt "$APP/Contents/Resources/Fonts/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>local.nerdrkeys</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

mkdir -p "$HOME/Applications"
pkill -x "$NAME" 2>/dev/null || true
rm -rf "$HOME/Applications/$APP"
cp -R "$APP" "$HOME/Applications/"
open "$HOME/Applications/$APP"
echo "Installed and launched ~/Applications/$APP"
