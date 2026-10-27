import AppKit
import CoreGraphics
import Foundation
import Observation

/// Manages macOS Screen Recording permissions using CoreGraphics APIs.
@MainActor
@Observable
final class ScreenCapturePermissionManager {
    static let shared = ScreenCapturePermissionManager()

    /// True if Screen Recording permission has been granted by the user.
    var isGranted: Bool = false

    /// Controls visibility of the permission alert / onboarding sheet.
    var showPermissionPrompt: Bool = false

    private var pollTimer: Task<Void, Never>?

    private init() {
        let granted = checkPermission()
        if !granted {
            showPermissionPrompt = true
            startPolling()
        }
    }

    /// Checks permission status silently using CGPreflightScreenCaptureAccess.
    @discardableResult
    func checkPermission() -> Bool {
        isGranted = CGPreflightScreenCaptureAccess()
        if isGranted {
            showPermissionPrompt = false
            stopPolling()
        }
        return isGranted
    }

    /// Triggers the macOS system prompt and opens System Settings if already denied.
    func requestPermission() {
        let requested = CGRequestScreenCaptureAccess()
        if requested {
            checkPermission()
        } else {
            openSettings()
        }
        startPolling()
    }

    /// Opens System Settings directly to Privacy & Security > Screen Recording.
    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Polls periodically while permission is missing so changes in System Settings are detected automatically.
    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                if checkPermission() {
                    break
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }
}
