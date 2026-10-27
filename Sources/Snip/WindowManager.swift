import AppKit
import SwiftUI

/// Coordinates between the floating compact HUD panel and the full main window.
@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()

    private(set) var floatingPanel: FloatingChatWindow?
    var activeScreenshotId: UUID?

    private init() {}

    /// Show only the floating HUD for a given screenshot (main window stays hidden).
    func showFloatingPanel(for screenshotId: UUID) {
        activeScreenshotId = screenshotId
        if floatingPanel == nil {
            let panel = FloatingChatWindow()
            floatingPanel = panel
        }
        floatingPanel?.updateScreenshot(id: screenshotId)
        floatingPanel?.orderFrontRegardless()
        floatingPanel?.makeKey()
    }

    /// Hide the floating panel.
    func hideFloatingPanel() {
        floatingPanel?.orderOut(nil)
    }

    /// Expand from floating HUD → main window, hide HUD.
    func expandToMainWindow() {
        hideFloatingPanel()
        NSApp.unhideWithoutActivation()
        NSApp.activate(ignoringOtherApps: true)
        // Find and show the main window
        for window in NSApp.windows where !window.isSheet && !(window is FloatingChatWindow) {
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        NSApp.windows.first(where: { !($0 is FloatingChatWindow) })?.makeKeyAndOrderFront(nil)
    }

    /// Detach from main window → floating panel, hide main window.
    func detachToFloating(screenshotId: UUID) {
        // Hide main window
        for window in NSApp.windows where !window.isSheet && !(window is FloatingChatWindow) {
            if window.canBecomeMain {
                window.orderOut(nil)
            }
        }
        showFloatingPanel(for: screenshotId)
    }
}
