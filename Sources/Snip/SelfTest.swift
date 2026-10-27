import AppKit
import Foundation
import SnipKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Snip-self-store ~/Applications/Snip.app/Contents/MacOS/Snip --selftest
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a test directory in /tmp")
            finish(code: 1)
            return
        }

        Task {
            try? await Task.sleep(for: .seconds(0.3))

            let before = model.screenshots.count

            // 1. Add screenshot check
            let dummyData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // Minimal PNG magic
            model.addScreenshot(imageData: dummyData, title: "  Test Snip   Title  ")
            check("addScreenshot increases count", model.screenshots.count == before + 1)
            check("selected screenshot matches new item", model.selectedScreenshot?.id == model.selection)
            check("title is cleaned", model.selectedScreenshot?.title == "Test Snip Title")

            guard let testShot = model.selectedScreenshot else {
                finish(code: 1)
                return
            }

            // 2. Add User message check
            model.addMessage(to: testShot, role: .user, content: "Can you explain this screen?")
            check("User message is appended", testShot.messages.count == 1)
            check("Message role is user", testShot.messages.first?.role == .user)

            // 3. Add Assistant markdown message check
            let markdownSample = """
                # Overview
                This is a **test analysis**.
                - Item 1
                - Item 2
                """
            model.addMessage(to: testShot, role: .assistant, content: markdownSample)
            check("Assistant message is appended", testShot.messages.count == 2)
            check("Message role is assistant", testShot.messages.last?.role == .assistant)

            // 4. Persistence check
            let reloaded = Store.loadScreenshots(from: model.storeDirectory)
            check("Persistence correctly writes manifest", reloaded.contains { $0.id == testShot.id })
            if let savedShot = reloaded.first(where: { $0.id == testShot.id }) {
                check("Saved shot has both messages", savedShot.messages.count == 2)
            }

            // 5. Delete screenshot check
            model.deleteScreenshot(testShot)
            check("deleteScreenshot removes item", model.screenshots.count == before)

            // 6. Title cleaner utility
            check("ItemTitle clean utility", ItemTitle.clean("  Another   Test  ") == "Another Test")

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        exit(code)
    }
}
