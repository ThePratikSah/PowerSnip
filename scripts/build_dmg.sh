#!/bin/zsh
# ==============================================================================
# build_dmg.sh — Builds a polished, branded macOS DMG installer for Snip
#
# Features:
#   1. Custom Volume Icon: Both the .dmg file and the mounted volume display Snip's icon.
#   2. Branded Installer Window Layout:
#      - Fixed window dimensions: 660 x 420 pt (Retina 1320 x 840 px)
#      - Clean modern background with "Drag to Install" arrow indicator
#      - Large clear icons (128x128 pt)
#      - Left side: Snip.app at (170, 200)
#      - Right side: /Applications symlink at (490, 200)
#      - Clean titlebar showing "Snip Installer"
#      - Toolbar, path bar, and status bar hidden
#      - Cleaned of any .DS_Store, ._*, or .Trashes clutter
#
# Usage:
#   ./scripts/build_dmg.sh
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" ./scripts/build_dmg.sh
# ==============================================================================
set -euo pipefail

script_dir=${0:A:h}
repo_dir=${script_dir:h}
dist_dir="$repo_dir/dist"
app_path="$HOME/Applications/Snip.app"
vol_name="Snip Installer"
final_dmg="$dist_dir/Snip-Installer.dmg"

echo "============================================================"
echo " Building Branded macOS DMG Installer for Snip"
echo "============================================================"

# 1. Ensure fresh Snip.app build exists
if [[ ! -d "$app_path" || " $* " == *" --rebuild "* ]]; then
  echo "==> 1. Building Snip.app release bundle..."
  "$repo_dir/build.sh"
else
  echo "==> 1. Using existing Snip.app at $app_path"
fi

# 2. Locate Snip icon (.icns)
icon_icns="$repo_dir/Resources/Snip.icns"
if [[ ! -f "$icon_icns" ]]; then
  icon_icns="$repo_dir/Resources/AppIcon.icns"
fi
if [[ ! -f "$icon_icns" ]]; then
  echo "==> Generating icon from Assets.xcassets..."
  "$repo_dir/tools/make_icon.sh"
  icon_icns="$repo_dir/Resources/AppIcon.icns"
fi
cp -f "$icon_icns" "$repo_dir/Resources/Snip.icns" 2>/dev/null || true
echo "==> Icon source: $icon_icns"

# 3. Prepare distribution directory
mkdir -p "$dist_dir"
rm -f "$final_dmg"

# 4. Unmount any previous instance of the volume
if [[ -d "/Volumes/$vol_name" ]]; then
  echo "==> Unmounting stale volume /Volumes/$vol_name..."
  hdiutil detach "/Volumes/$vol_name" -force 2>/dev/null || true
fi

# 5. Create staging directory
stage_dir=$(mktemp -d /tmp/snip_dmg_stage.XXXXXX)
trap 'rm -rf "$stage_dir"' EXIT

echo "==> 2. Assembling DMG staging hierarchy..."
mkdir -p "$stage_dir/.background"

# Generate crisp Retina background image (1320x840 px @ 144 DPI for 660x420 pt window)
swift "$script_dir/generate_dmg_background.swift" "$stage_dir/.background/background.png"

# Copy App bundle and create /Applications symlink
cp -R "$app_path" "$stage_dir/Snip.app"
ln -s /Applications "$stage_dir/Applications"

# Copy volume icon to root
cp "$icon_icns" "$stage_dir/.VolumeIcon.icns"

# 6. Create temporary read-write disk image
temp_rw_dmg="/tmp/Snip_Temp_RW_$$.dmg"
rm -f "$temp_rw_dmg"
echo "==> 3. Creating read-write DMG container..."
hdiutil create \
  -volname "$vol_name" \
  -srcfolder "$stage_dir" \
  -fs HFS+ \
  -format UDRW \
  -ov "$temp_rw_dmg" >/dev/null

# 7. Mount temporary DMG
echo "==> 4. Mounting DMG for layout and view styling..."
mount_output=$(hdiutil attach -readwrite -noverify -noautoopen "$temp_rw_dmg")
dev_node=$(echo "$mount_output" | grep -E '^/dev/' | head -1 | awk '{print $1}')
mount_point="/Volumes/$vol_name"

if [[ -z "$dev_node" || ! -d "$mount_point" ]]; then
  echo "Error: Failed to mount temporary disk image."
  exit 1
fi
echo "Mounted at: $mount_point ($dev_node)"

# 8. Set custom volume icon attributes on mounted volume
echo "==> 5. Setting custom volume icon..."
SetFile -c icnC "$mount_point/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a V "$mount_point/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "$mount_point" 2>/dev/null || true
SetFile -a V "$mount_point/.background" 2>/dev/null || true

# 9. Configure Finder window view options via AppleScript
echo "==> 6. Applying Finder window dimensions, background, and icon coordinates..."
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$vol_name"
        open
        delay 0.5
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        
        -- Window position and dimensions: 660 x 420 pt
        set the bounds of container window to {160, 100, 160 + 660, 100 + 420}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Exact icon placement (x, y)
        -- Left: Snip.app at (170, 200)
        -- Right: Applications at (490, 200)
        set position of item "Snip.app" of container window to {170, 200}
        set position of item "Applications" of container window to {490, 200}
        
        update without registering applications
        delay 1.5
        close
    end tell
end tell
APPLESCRIPT

# 10. Clean up hidden clutter (.Trashes, .fseventsd, ._*)
echo "==> 7. Sanitizing volume filesystem..."
rm -rf "$mount_point/.Trashes" "$mount_point/.fseventsd" 2>/dev/null || true
find "$mount_point" -name '._*' -delete 2>/dev/null || true

# Re-affirm volume icon attribute after AppleScript / Finder touches
SetFile -a C "$mount_point" 2>/dev/null || true

# Ensure writes are flushed to disk
sync
sleep 1

# 11. Detach read-write DMG
echo "==> 8. Detaching volume..."
hdiutil detach "$dev_node" >/dev/null || diskutil eject "$dev_node" >/dev/null

# 12. Convert to final read-only compressed UDZO DMG
echo "==> 9. Compressing final DMG with zlib-9 (UDZO)..."
hdiutil convert "$temp_rw_dmg" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$final_dmg" >/dev/null
rm -f "$temp_rw_dmg"

# 13. Set custom icon on the .dmg file itself in Finder
echo "==> 10. Setting custom icon on the .dmg file..."
swift -e "
import AppKit
let ws = NSWorkspace.shared
if let img = NSImage(contentsOfFile: \"$icon_icns\") {
    _ = ws.setIcon(img, forFile: \"$final_dmg\", options: [])
}
"
SetFile -a C "$final_dmg" 2>/dev/null || true

# 14. Code sign DMG if identity is provided
identity="${SIGN_IDENTITY:-}"
if [[ -n "$identity" && "$identity" != "-" ]]; then
  echo "==> 11. Signing DMG with identity: $identity"
  codesign --force --sign "$identity" "$final_dmg"
fi

echo ""
echo "============================================================"
echo " DMG Build Complete!"
echo " Output: $final_dmg"
echo " Size:   $(ls -lh "$final_dmg" | awk '{print $5}')"
echo "============================================================"

# Quick verification of the custom icon attribute
file_attrs=$(GetFileInfo -a "$final_dmg" 2>/dev/null || true)
if [[ "$file_attrs" =~ "C" ]]; then
  echo " [✓] DMG file has custom icon attribute (C)"
else
  echo " [!] Note: Custom icon attribute check: $file_attrs"
fi

echo ""
echo "You can mount and inspect the installer by running:"
echo "  open \"$final_dmg\""
echo "============================================================"
