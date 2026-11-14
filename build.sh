#!/bin/bash
# Builds NerdrKeys.app and installs it to ~/Applications. Re-run after editing main.swift.
set -euo pipefail
cd "$(dirname "$0")"

NAME="NerdrKeys"
APP="$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -o "$APP/Contents/MacOS/$NAME" main.swift

# App icon for Finder, Spotlight and Launchpad. Regenerate it with icon/make-icon.sh.
cp AppIcon.icns "$APP/Contents/Resources/"

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
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

mkdir -p "$HOME/Applications"
pkill -x "$NAME" 2>/dev/null || true
rm -rf "$HOME/Applications/$APP"
# Move (not copy) so only one NerdrKeys.app exists; a leftover build copy here
# shows up as a duplicate in Spotlight.
mv "$APP" "$HOME/Applications/"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Applications/$APP" || true
open "$HOME/Applications/$APP"
echo "Installed and launched ~/Applications/$APP"
