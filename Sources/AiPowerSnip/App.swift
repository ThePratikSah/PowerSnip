import AppKit
import SwiftUI

// AiPowerSnip
//   AiPowerSnip                      the app
//   APP_STORE=<dir> AiPowerSnip      use another store directory (tests, experiments)
//   APP_SNAPSHOT=<dir> AiPowerSnip   save a PNG of every sidebar page and Settings tab in light and dark mode, then quit
//   APP_SEED=1 AiPowerSnip           fill an empty store with sample items (tools/snap.sh)
//   AiPowerSnip --selftest           run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> AiPowerSnip      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 AiPowerSnip           draw the 8 pt grid and the layout probes over the window

@main
struct AiPowerSnipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("AiPowerSnip", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 750)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Snip Section…") {
                    Task { await ScreenCapture.captureSelection(model: model) }
                }
                .keyboardShortcut("4", modifiers: [.command, .option, .shift])

                Button("Capture Full Screen") {
                    Task { await ScreenCapture.captureFullScreen(model: model) }
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            }
        }

        // Keep running in menu bar as a background utility
        MenuBarExtra("AiPowerSnip", systemImage: "camera.viewfinder") {
            Button("Snip Section (⌥⇧⌘4)") {
                Task { await ScreenCapture.captureSelection(model: model) }
            }
            .keyboardShortcut("4", modifiers: [.command, .option, .shift])

            Button("Capture Full Screen (⇧⌘3)") {
                Task { await ScreenCapture.captureFullScreen(model: model) }
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])

            Divider()

            Button("Open AiPowerSnip Window") {
                AppDelegate.showMainWindow()
            }

            Divider()

            Button("Quit AiPowerSnip") {
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

        // Hook main window to prevent deallocation on close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) {
                self?.mainWindow = window
                window.delegate = self
            }
        }

        // Register system-wide global hotkeys (Cmd+Opt+Shift+4 and Cmd+Shift+4)
        GlobalHotKeyManager.shared.register {
            Task { @MainActor in
                if let model = AppModel.shared {
                    await ScreenCapture.captureSelection(model: model)
                    Self.showMainWindow()
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
            if window.canBecomeMain || window.title.contains("AiPowerSnip") || window.title.contains("Snip") {
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
