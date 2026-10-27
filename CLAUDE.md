# Snip

A native macOS app in SwiftUI for capturing screenshots and AI multimodal analysis.

## Layout

- `Sources/Snip/` the app. `App.swift` has the window, menus, and the database location.
- `Sources/SnipKit/` rules and data logic with no SwiftUI. Tests in `Tests/SnipKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/Snip.app`.
- `Icon/AppIcon.icon` the app icon. `build.sh` compiles it with `tools/make_icon.sh`.
- `docs/` the brief, the screen index, and the user stories.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build.
- Unit tests: `swift test --scratch-path ~/Library/Developer/Snip/test-build`.
- Self-test (the app's real functions on a /tmp store): `tools/selftest.sh`. Exit 0 when every check passes.
- Snapshots: `tools/snap.sh`. Writes to `/tmp/Snip-shots/`.
- Never test against the real database in `~/Library/Application Support/Snip/`.

## Design rules

- Use Apple's controls and system styles.
- Window chrome: Clean headerless window (`.windowStyle(.hiddenTitleBar)`), no app bar or title header. Entire screen dedicated to content.
- Global shortcut: `⌘⌥⇧4` (`⌥⇧⌘4`) only. Does not conflict with macOS default shortcuts.
- Liquid Glass belongs to floating controls only, never to content.

## Git

- Commit after each working change, with a message that says what the user can now do.
