# Snip: AI Screenshot Assistant with Dynamic Gemini REST API

A native macOS application for capturing screen snippets and performing multimodal AI analysis using Google Gemini.

---

## 1. Dynamic Model Discovery & Image Analysis (Gemini REST API)

Snip integrates directly with the official Google Gemini REST API (`v1beta`) using native Swift URLSession with **zero external dependencies**.

### Key Features
- **Dynamic Model Discovery (`GeminiService.getMultimodalModels`)**:
  - Queries `https://generativelanguage.googleapis.com/v1beta/models`.
  - Filters out deprecated, discontinued, legacy, embedding, and non-multimodal models.
  - Dynamically populates the model picker with current official models (e.g. `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-1.5-pro`, `gemini-1.5-flash`).
  - Automatically falls back to curated official models if offline.
- **Multimodal Image Analysis (`GeminiService.generateAnalysis`)**:
  - Sends inline Base64 PNG image data and user query to `https://generativelanguage.googleapis.com/v1beta/{model}:generateContent`.
  - Handles rate limits, quota issues, and returns Markdown analysis.

---

## 2. Snip macOS Application

- **Designated Global Hotkey**:
  - Press **`⌘⌥⇧4`** (`⌥⇧⌘4`) from any app to drag and snip a section of your screen.
  - Does **not** conflict with or override macOS default screenshot hotkeys (`⌘⇧4` or `⌘⇧3`).
- **Clean Headerless Interface**:
  - Borderless, clean window with no bulky top app bar or header. The entire window displays your content.
- **App Icon**:
  - Built from official macOS asset catalog (`Assets.xcassets/AppIcon.appiconset`) with multi-resolution renditions up to 1024x1024 (`AppIcon.icns`).
- **Background Execution**:
  - Runs silently in the background with a top menu bar status item (`camera.viewfinder`).
  - Hotkey triggers screen capture even when other apps are focused or the main window is hidden.
- **Pure Light Mode Chat**:
  - The AI analysis chat overlay box is locked to 100% Light Mode with a crisp, solid white card background for maximum readability regardless of system dark mode or dark screenshots.
- **Rich Markdown Formatting**:
  - Structured renderer with support for headers, bullet points, numbered lists, blockquotes, and code blocks with one-click copy buttons.
- **Privacy Protection**:
  - Built-in screen share & recording protection (`NSWindow.SharingType.none`) toggleable via **`⌥⌘P`** or Settings to exclude Snip from Zoom, Google Meet, Teams, Slack, and screenshots.
  - Your Gemini API key is stored locally on your Mac in `UserDefaults` and is never sent anywhere except directly to Google Gemini.
  - Chat history and screenshots are stored locally in `~/Library/Application Support/Snip/manifest.json`.

---

## 3. Building & Running Locally

### Requirements
- macOS 14.0 or newer
- Swift 6 toolchain (`CommandLineTools` or Xcode)

### Local Build and Install
```bash
cd AiPowerSnip
./build.sh
```

The compiled app is installed to `~/Applications/Snip.app`.

### Launch the App
```bash
open ~/Applications/Snip.app
```

---

## 4. Producing a Build for Distribution

To distribute **Snip** to other macOS users outside the Mac App Store, you can create a standalone **Installer DMG** and a **Zip archive**, signed and notarized by Apple.

### Option A: One-Step Automated Distribution Script

Run the automated distribution script from the `AiPowerSnip` directory:

```bash
cd AiPowerSnip
./tools/distribute.sh
```

This performs the following steps automatically:
1. Compiles the release binary with Swift optimization.
2. Compiles `Assets.xcassets/AppIcon.appiconset` into `AppIcon.icns` (and `Assets.car`).
3. Assembles the signed `.app` bundle into `~/Applications/Snip.app`.
4. Packages a standalone ZIP archive at `dist/Snip-macOS.zip` (preserving macOS file attributes).
5. Packages a drag-and-drop installer disk image at `dist/Snip-Installer.dmg`.

---

### Option B: Signed Release Build (Apple Developer ID)

For distribution to public users without triggering Gatekeeper security warnings:

#### 1. List Available Signing Identities
```bash
security find-identity -v -p codesigning
```
Look for your `Developer ID Application: Your Name (TEAM_ID)` certificate.

#### 2. Run Distribution Build with Signing & Hardened Runtime
```bash
cd AiPowerSnip
SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" ./tools/distribute.sh
```

#### 3. Submit for Apple Notarization
Submit the generated DMG or ZIP file to Apple's Notary Service:

```bash
xcrun notarytool submit "dist/Snip-Installer.dmg" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait
```
*(Note: Create an app-specific password at [appleid.apple.com](https://appleid.apple.com)).*

#### 4. Staple the Notarization Ticket
Once notarization succeeds, attach the ticket directly to the disk image so users can open it offline:

```bash
xcrun stapler staple "dist/Snip-Installer.dmg"
```

#### 5. Verify the Final Build
Verify that Gatekeeper will accept the application without security alerts:

```bash
spctl --assess --type open --context context:primary-signature --verbose "dist/Snip-Installer.dmg"
```

---

### Manual Step-by-Step Distribution Commands (For CI/CD)

If you are setting up a GitHub Actions workflow or custom CI/CD runner:

```bash
# 1. Compile Release Binary
swift build -c release --package-path . --scratch-path .build

# 2. Compile Icons from Assets.xcassets
mkdir -p /tmp/AppIcon.iconset
cp Assets.xcassets/AppIcon.appiconset/*.png /tmp/AppIcon.iconset/
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
rm -rf /tmp/AppIcon.iconset

# 3. Assemble .app Bundle
mkdir -p Snip.app/Contents/MacOS Snip.app/Contents/Resources
cp .build/release/Snip Snip.app/Contents/MacOS/Snip
cp Resources/AppIcon.icns Snip.app/Contents/Resources/
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" Info.plist.in > Snip.app/Contents/Info.plist

# 4. Code Sign with Hardened Runtime
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAM_ID)" Snip.app

# 5. Create DMG Installer
mkdir -p dmg_folder
cp -R Snip.app dmg_folder/
ln -s /Applications dmg_folder/Applications
hdiutil create -volname "Snip" -srcfolder dmg_folder -ov -format UDZO Snip-Installer.dmg
rm -rf dmg_folder
```
