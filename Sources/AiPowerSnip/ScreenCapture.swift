import AppKit
import ScreenCaptureKit

/// Captures screenshots cleanly on macOS.
enum ScreenCapture {
    /// Captures the main screen, hiding the app during capture if needed.
    static func capture(model: AppModel) async {
        model.isCapturing = true
        defer { model.isCapturing = false }

        // Hide app briefly so it does not appear in the shot
        NSApp.hide(nil)
        try? await Task.sleep(for: .milliseconds(400))

        var capturedData: Data? = nil

        // Method 1: ScreenCaptureKit
        if #available(macOS 14.0, *) {
            capturedData = await captureViaScreenCaptureKit()
        }

        // Method 2: screencapture CLI fallback (guaranteed on all macOS)
        if capturedData == nil {
            capturedData = captureViaCLI()
        }

        // Restore app
        NSApp.unhideWithoutActivation()
        NSApp.activate()

        if let data = capturedData {
            model.addScreenshot(imageData: data)
        } else {
            print("Failed to capture screenshot")
        }
    }

    @available(macOS 14.0, *)
    private static func captureViaScreenCaptureKit() async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }

            let appBundleID = Bundle.main.bundleIdentifier ?? ""
            let excludedWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == appBundleID }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

            let config = SCStreamConfiguration()
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            config.width = Int(display.frame.width * scale)
            config.height = Int(display.frame.height * scale)
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return pngData(from: image)
        } catch {
            print("ScreenCaptureKit error: \(error)")
            return nil
        }
    }

    private static func captureViaCLI() -> Data? {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("snip_\(UUID().uuidString).png")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-x", "-m", tempFile.path]
        try? proc.run()
        proc.waitUntilExit()

        guard FileManager.default.fileExists(atPath: tempFile.path) else { return nil }
        let data = try? Data(contentsOf: tempFile)
        try? FileManager.default.removeItem(at: tempFile)
        return data
    }

    private static func pngData(from cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
