#!/bin/zsh
set -euo pipefail
here=${0:A:h}
repo=${here:h}
mkdir -p "$repo/Resources"

# Find AppIcon.appiconset either in repo or parent workspace
iconset_src=""
if [[ -d "$repo/Assets.xcassets/AppIcon.appiconset" ]]; then
  iconset_src="$repo/Assets.xcassets/AppIcon.appiconset"
elif [[ -d "$repo/../Assets.xcassets/AppIcon.appiconset" ]]; then
  iconset_src="$repo/../Assets.xcassets/AppIcon.appiconset"
fi

if [[ -n "$iconset_src" ]]; then
  echo "Compiling AppIcon.icns from $iconset_src..."
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  
  target_iconset="$work/AppIcon.iconset"
  mkdir -p "$target_iconset"
  cp "$iconset_src"/*.png "$target_iconset/"
  
  /usr/bin/iconutil -c icns "$target_iconset" -o "$repo/Resources/AppIcon.icns"
  echo "Successfully generated Resources/AppIcon.icns"
  
  # Try compiling Assets.car with actool if full Xcode is installed
  if xcrun --find actool >/dev/null 2>&1; then
    xcrun actool "${iconset_src:h}" --compile "$repo/Resources" --platform macosx \
      --minimum-deployment-target 14.0 --app-icon AppIcon \
      --output-format human-readable-text >/dev/null 2>&1 || true
  fi
  
  # Ensure Assets.car exists
  if [[ ! -f "$repo/Resources/Assets.car" ]]; then
    touch "$repo/Resources/Assets.car"
  fi
else
  # Fallback to procedural icon generator if no iconset is present
  swift "$here/make_icon.swift" "$repo"
fi
