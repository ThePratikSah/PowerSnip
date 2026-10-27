#!/bin/zsh
# Builds, packages, and prepares Snip for macOS distribution (DMG & Zip).
#
# Usage:
#   tools/distribute.sh
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" tools/distribute.sh
set -euo pipefail

here=${0:A:h}
repo=${here:h}
dist="$repo/dist"
app="$HOME/Applications/Snip.app"

echo "==> 1. Building release app bundle with new icon..."
"$repo/build.sh"

echo "==> 2. Preparing distribution output directory..."
rm -rf "$dist"
mkdir -p "$dist"

# Sign with hardened runtime if Developer ID is present
identity="${SIGN_IDENTITY:-}"
if [[ -n "$identity" && "$identity" != "-" ]]; then
  echo "==> Signing with hardened runtime using identity: $identity"
  codesign --force --deep --options runtime --timestamp --sign "$identity" "$app"
  codesign --verify --deep --strict --verbose=2 "$app"
fi

echo "==> 3. Creating standalone Zip archive..."
# ditto preserves resource forks and HFS metadata for macOS apps
ditto -c -k --keepParent "$app" "$dist/Snip-macOS.zip"
echo "Created: dist/Snip-macOS.zip"

echo "==> 4. Creating Branded Drag-and-Drop DMG Installer..."
"$repo/scripts/build_dmg.sh"

echo ""
echo "======================================================="
echo " Distribution artifacts ready in: $dist"
echo "   - $dist/Snip-Installer.dmg"
echo "   - $dist/Snip-macOS.zip"
echo "======================================================="
echo ""
echo "Next Steps for Public Distribution (Apple Gatekeeper / Notarization):"
echo "  xcrun notarytool submit \"$dist/Snip-Installer.dmg\" \\"
echo "    --apple-id \"developer@example.com\" \\"
echo "    --team-id \"TEAM_ID\" \\"
echo "    --password \"app-specific-password\" \\"
echo "    --wait"
echo ""
echo "  xcrun stapler staple \"$dist/Snip-Installer.dmg\""
echo "======================================================="
