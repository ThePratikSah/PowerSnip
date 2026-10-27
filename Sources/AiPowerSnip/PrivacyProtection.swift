import AppKit
import SwiftUI

// MARK: - Screen Capture & Screen Share Protection for macOS
//
// Mechanism:
// - Uses AppKit's `NSWindow.sharingType = .none` to prevent the WindowServer from
//   sharing the window's pixel buffer with other processes.
// - Compatible with ScreenCaptureKit, CoreGraphics (CGWindowListCreateImage),
//   native macOS screenshot tools (`screencapture`, ⌘⇧3, ⌘⇧4), and conferencing apps
//   (Google Meet, Zoom, Microsoft Teams, Slack, Discord, QuickTime).
//
// Limitations:
// - Hardware capture devices (HDMI/DisplayPort capture cards, hardware splitters)
//   capture the physical GPU video raster output below WindowServer and cannot be
//   prevented via user-space software APIs.
// - Kernel-level or hypervisor-level screen grabbers bypass WindowServer compositing.

// MARK: - 1. Privacy Protection Manager

/// Manages screen capture visibility across all application windows.
@MainActor
@Observable
public final class PrivacyProtectionManager {
    public static let shared = PrivacyProtectionManager()

    private static let defaultsKey = "PrivacyScreenCaptureBlocked"

    /// When `true`, windows are excluded from screen captures and sharing tools (`.none`).
    /// When `false`, windows are visible to capture tools (`.readOnly`).
    public var isScreenCaptureBlocked: Bool {
        didSet {
            UserDefaults.standard.set(isScreenCaptureBlocked, forKey: Self.defaultsKey)
            applyProtectionToAllWindows()
        }
    }

    private init() {
        // Reads saved preference, defaulting to false (or true for high-security environments)
        self.isScreenCaptureBlocked = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? false

        // Ensure protection is applied once windows are ordered and initialized
        DispatchQueue.main.async { [weak self] in
            self?.applyProtectionToAllWindows()
        }
    }

    /// Applies the sharingType to all open application windows and their child panels/sheets.
    public func applyProtectionToAllWindows() {
        let targetType: NSWindow.SharingType = isScreenCaptureBlocked ? .none : .readOnly
        for window in NSApp.windows {
            window.sharingType = targetType
            for child in window.childWindows ?? [] {
                child.sharingType = targetType
            }
        }
    }

    /// Configures a newly created or resolved window with the current privacy policy.
    public func configure(window: NSWindow) {
        window.setScreenCaptureProtected(isScreenCaptureBlocked)
    }
}

// MARK: - 2. AppKit Extensions

public extension NSWindow {
    /// Sets whether this window (and any child panels/sheets) is protected from screen capture and screen sharing.
    ///
    /// - Parameter protected: If `true`, sets `sharingType = .none`. If `false`, sets `sharingType = .readOnly`.
    func setScreenCaptureProtected(_ protected: Bool) {
        self.sharingType = protected ? .none : .readOnly
        for child in childWindows ?? [] {
            child.setScreenCaptureProtected(protected)
        }
    }
}

public extension NSWindowController {
    /// Configures screen capture protection for the window controller's managed window.
    func setScreenCaptureProtected(_ protected: Bool) {
        window?.setScreenCaptureProtected(protected)
    }
}

// MARK: - 3. Window Accessor (NSViewRepresentable)

/// Hooks into the AppKit view hierarchy to locate the backing NSWindow safely across window lifecycle stages.
public struct WindowAccessor: NSViewRepresentable {
    public let callback: (NSWindow?) -> Void

    public init(callback: @escaping (NSWindow?) -> Void) {
        self.callback = callback
    }

    public func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        view.onWindowResolved = callback
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            callback(window)
        }
    }

    private final class WindowObserverView: NSView {
        var onWindowResolved: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                // Defer to next runloop tick to allow SwiftUI layout and window ordering to complete
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let window = window else { return }
                    self?.onWindowResolved?(window)
                }
            }
        }
    }
}

// MARK: - 4. SwiftUI View Modifier

/// A SwiftUI ViewModifier that controls the screen capture protection of its parent window.
public struct ScreenCaptureProtectionModifier: ViewModifier {
    public let isProtected: Bool

    public init(isProtected: Bool) {
        self.isProtected = isProtected
    }

    public func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    guard let window = window else { return }
                    window.setScreenCaptureProtected(isProtected)
                }
            )
            .onChange(of: isProtected) { _, newValue in
                PrivacyProtectionManager.shared.applyProtectionToAllWindows()
            }
    }
}

public extension View {
    /// Hides or reveals this view's parent window from screen recording, screen sharing, and screenshots.
    ///
    /// - Parameter isProtected: `true` to block capture (`NSWindow.SharingType.none`), `false` to permit (`.readOnly`).
    func protectFromScreenCapture(_ isProtected: Bool = true) -> some View {
        modifier(ScreenCaptureProtectionModifier(isProtected: isProtected))
    }
}
