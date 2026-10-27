import AppKit

/// Captures screenshots cleanly on macOS, supporting interactive area selection and full screen.
enum ScreenCapture {
    /// Captures a selected section of the screen interactively using crosshairs.
    /// User can drag to select any region, hit Space to select a specific window, or Escape to cancel.
    static func captureSelection(model: AppModel) async {
        await executeCapture(mode: .interactive, model: model)
    }

    /// Captures the full primary screen.
    static func captureFullScreen(model: AppModel) async {
        await executeCapture(mode: .fullScreen, model: model)
    }

    private enum Mode {
        case interactive
        case fullScreen
    }

    private static func executeCapture(mode: Mode, model: AppModel) async {
        // Verify Screen Recording permission before launching capture
        if !ScreenCapturePermissionManager.shared.checkPermission() {
            ScreenCapturePermissionManager.shared.showPermissionPrompt = true
            ScreenCapturePermissionManager.shared.requestPermission()
            return
        }

        model.isCapturing = true
        defer { model.isCapturing = false }

        // Hide app so it does not block what the user wants to snip
        NSApp.hide(nil)
        try? await Task.sleep(for: .milliseconds(300))

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("snip_\(UUID().uuidString).png")

        // Run screencapture process off the main thread so UI doesn't hang
        let capturedData: Data? = await Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

            switch mode {
            case .interactive:
                // -i: capture screen interactively by mouse selection
                // -x: do not play camera shutter sound
                proc.arguments = ["-i", "-x", tempFile.path]
            case .fullScreen:
                // -m: only capture main monitor
                // -x: do not play sound
                proc.arguments = ["-m", "-x", tempFile.path]
            }

            do {
                try proc.run()
                proc.waitUntilExit()

                if FileManager.default.fileExists(atPath: tempFile.path) {
                    let data = try? Data(contentsOf: tempFile)
                    try? FileManager.default.removeItem(at: tempFile)
                    return data
                }
            } catch {
                print("Failed to run screencapture: \(error)")
            }
            return nil
        }.value

        // Restore and activate app
        NSApp.unhideWithoutActivation()
        NSApp.activate()

        if let data = capturedData, !data.isEmpty {
            let titlePrefix = (mode == .interactive) ? "Snip" : "Screen"
            let title = "\(titlePrefix) \(DateFormatter.shortFormat.string(from: .now))"
            model.addScreenshot(imageData: data, title: title)

            // Show floating HUD instead of main window for hotkey-triggered captures
            if let id = model.selection {
                WindowManager.shared.showFloatingPanel(for: id)
            }

            // Generate AI title in background (non-fatal if it fails)
            if let screenshot = model.selectedScreenshot {
                screenshot.isGeneratingTitle = true
                Task {
                    await TitleGenerator.generateTitle(for: screenshot, model: model)
                }
            }
        }
    }
}
