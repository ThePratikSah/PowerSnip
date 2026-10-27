import AppKit
import SwiftUI

// Snip
//   Snip                            the app
//   APP_STORE=<dir> Snip            use another store directory (tests, experiments)
//   APP_SNAPSHOT=<dir> Snip         save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 Snip                 fill an empty store with sample items (tools/snap.sh)
//   Snip --selftest                 run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> Snip            run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 Snip                 draw the 8 pt grid and the layout probes over the window

@main
struct SnipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .protectFromScreenCapture(PrivacyProtectionManager.shared.isScreenCaptureBlocked)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 750)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Toggle("Hide from Screen Share & Capture", isOn: Binding(
                    get: { PrivacyProtectionManager.shared.isScreenCaptureBlocked },
                    set: { PrivacyProtectionManager.shared.isScreenCaptureBlocked = $0 }
                ))
                .keyboardShortcut("P", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .newItem) {
                Button("Snip Section…") {
                    Task { await ScreenCapture.captureSelection(model: model) }
                }
                .keyboardShortcut("4", modifiers: [.command, .option, .shift])
            }
        }

        // Keep running in menu bar as a background utility
        MenuBarExtra("Snip", systemImage: "camera.viewfinder") {
            Button("Snip Section (⌥⇧⌘4)") {
                Task { await ScreenCapture.captureSelection(model: model) }
            }
            .keyboardShortcut("4", modifiers: [.command, .option, .shift])

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { LaunchAtLoginManager.shared.isEnabled },
                set: { LaunchAtLoginManager.shared.toggleLaunchAtLogin(enabled: $0) }
            ))

            Button("Open Snip Window") {
                AppDelegate.showMainWindow()
            }

            Divider()

            Button("Quit Snip") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        if SelfTest.requested {
            SelfTest.runIfRequested(model: AppModel.shared ?? AppModel())
            return
        }

        // Hook main window: hide titlebar and make background draggable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) {
                self?.mainWindow = window
                window.delegate = self
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
            }
        }

        // Register system-wide designated global hotkey: Cmd+Option+Shift+4 only
        GlobalHotKeyManager.shared.register {
            Task { @MainActor in
                if let model = AppModel.shared {
                    await ScreenCapture.captureSelection(model: model)
                    // WindowManager.showFloatingPanel is called inside ScreenCapture now
                }
            }
        }
    }

    /// Keep app running in background when window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopen window when clicking Dock icon
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showMainWindow()
        return true
    }

    /// Instead of destroying window on close, hide it so state is preserved
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    /// Shows and activates the main window
    static func showMainWindow() {
        NSApp.unhideWithoutActivation()
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !window.isSheet {
            if window.canBecomeMain || window.title.contains("Snip") {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        // Fallback to any window
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
