#!/bin/bash
# Regenerates AppIcon.icns from icon/draw.swift, using the glasses outline in main.swift.
# Only needed when you change the icon design; build.sh uses the committed AppIcon.icns.
#
# The icon is "slimmed": each size is reduced to a 256-colour palette with pngquant
# (brew install pngquant), then packed into the .icns as-is. Apple's iconutil would
# re-encode the PNGs and undo most of the saving (~115 KB here vs ~480 KB with iconutil).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v pngquant >/dev/null || { echo "Needs pngquant: brew install pngquant"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
{ echo "import AppKit"; sed -n '/^func glassesPath/,/^}/p' main.swift; } > "$tmp/glasses.swift"
cp icon/draw.swift "$tmp/main.swift"   # top-level code must live in a file named main.swift
swiftc -O -o "$tmp/draw" "$tmp/main.swift" "$tmp/glasses.swift"
"$tmp/draw" "$tmp/icon_1024.png"

# Every size macOS asks for, from the 1024 master.
set_dir="$tmp/AppIcon.iconset"; mkdir "$set_dir"
for s in 16 32 128 256 512; do
  sips -z $s $s "$tmp/icon_1024.png" --out "$set_dir/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$tmp/icon_1024.png" --out "$set_dir/icon_${s}x${s}@2x.png" >/dev/null
done

# Reduce colours (visually identical at icon sizes; the glow gets a faint grain at 4x zoom).
pngquant --quality=80-95 --speed 1 --strip --force --ext .png "$set_dir"/*.png

# Pack the PNGs straight into an .icns container (no re-encoding).
python3 -I - "$set_dir" AppIcon.icns <<'PY'
import os, struct, sys
d, out = sys.argv[1], sys.argv[2]
entries = [("icp4", "16x16"), ("ic11", "16x16@2x"), ("icp5", "32x32"), ("ic12", "32x32@2x"),
           ("ic07", "128x128"), ("ic13", "128x128@2x"), ("ic08", "256x256"), ("ic14", "256x256@2x"),
           ("ic09", "512x512"), ("ic10", "512x512@2x")]
body = b""
for kind, name in entries:
    data = open(os.path.join(d, f"icon_{name}.png"), "rb").read()
    body += kind.encode() + struct.pack(">I", len(data) + 8) + data
open(out, "wb").write(b"icns" + struct.pack(">I", len(body) + 8) + body)
PY

cp "$set_dir/icon_512x512@2x.png" icon/AppIcon-1024.png   # preview, same slimmed image
echo "Wrote AppIcon.icns ($(du -h AppIcon.icns | cut -f1)) and icon/AppIcon-1024.png"
