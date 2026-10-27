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
                .frame(minWidth: 860, minHeight: 540)
        }
        .defaultSize(width: 1160, height: 740)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Snip Section…") {
                    Task { await ScreenCapture.captureSelection(model: model) }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Capture Full Screen") {
                    Task { await ScreenCapture.captureFullScreen(model: model) }
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
