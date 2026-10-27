#!/bin/zsh
set -euo pipefail
here=${0:A:h}
repo=${here:h}
icon="$repo/Icon/AppIcon.icon"
mkdir -p "$repo/Resources"

if xcrun --find actool >/dev/null 2>&1; then
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  xcrun actool "$icon" --compile "$work" --platform macosx \
    --minimum-deployment-target 26.0 --app-icon AppIcon \
    --output-partial-info-plist "$work/partial.plist" \
    --output-format human-readable-text --errors --warnings >"$work/log" 2>&1 || { cat "$work/log"; exit 1; }
  [[ -f "$work/Assets.car" && -f "$work/AppIcon.icns" ]] || { cat "$work/log"; echo "actool wrote no icon"; exit 1; }
  cp "$work/Assets.car" "$work/AppIcon.icns" "$repo/Resources/"
  echo "wrote Resources/Assets.car and Resources/AppIcon.icns using actool"
else
  swift "$here/make_icon.swift" "$repo"
fi
