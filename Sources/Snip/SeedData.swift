import AppKit
import Foundation

/// Sample data for testing and snapshots: APP_SEED=1 fills an empty store
/// with a realistic sample screenshot and analysis response.
@MainActor
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be set")
            return
        }
        guard model.screenshots.isEmpty else { return }

        // Create a crisp sample UI graphic as the screenshot
        let size = NSSize(width: 800, height: 500)
        let image = NSImage(size: size, flipped: false) { rect in
            // Background
            let bg = NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.14, blue: 0.22, alpha: 1.0),
                                ending: NSColor(srgbRed: 0.20, green: 0.24, blue: 0.38, alpha: 1.0))
            bg?.draw(in: rect, angle: -45)

            // Mock Card
            let cardRect = NSRect(x: 80, y: 80, width: 640, height: 340)
            let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
            NSColor(srgbRed: 0.18, green: 0.20, blue: 0.30, alpha: 0.9).setFill()
            cardPath.fill()
            NSColor.white.withAlphaComponent(0.15).setStroke()
            cardPath.lineWidth = 1.5
            cardPath.stroke()

            // Header bar
            let headerText = "Analytics Dashboard • Q3 Performance" as NSString
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 22, weight: .bold)
            ]
            headerText.draw(at: NSPoint(x: 110, y: 360), withAttributes: headerAttrs)

            // Subtitle
            let subText = "Revenue: $148,200 (+24% YoY)  •  Active Users: 12,450" as NSString
            let subAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(srgbRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0),
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
            ]
            subText.draw(at: NSPoint(x: 110, y: 320), withAttributes: subAttrs)

            // Mock Chart Bars
            let barColors = [
                NSColor(srgbRed: 0.3, green: 0.6, blue: 0.95, alpha: 1.0),
                NSColor(srgbRed: 0.4, green: 0.7, blue: 0.95, alpha: 1.0),
                NSColor(srgbRed: 0.5, green: 0.8, blue: 0.95, alpha: 1.0),
                NSColor(srgbRed: 0.4, green: 0.85, blue: 0.7, alpha: 1.0),
                NSColor(srgbRed: 0.35, green: 0.8, blue: 0.6, alpha: 1.0)
            ]
            for (i, h) in [120.0, 160.0, 140.0, 210.0, 190.0].enumerated() {
                let bar = NSRect(x: 130 + Double(i) * 110, y: 110, width: 60, height: h)
                let barPath = NSBezierPath(roundedRect: bar, xRadius: 8, yRadius: 8)
                barColors[i].setFill()
                barPath.fill()
            }

            return true
        }

        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else { return }

        model.addScreenshot(imageData: pngData, title: "Q3 Metrics Dashboard")

        if let shot = model.screenshots.first {
            model.addMessage(to: shot, role: .user, content: "Summarize the revenue and active users from this screen.")
            model.addMessage(to: shot, role: .assistant, content: """
                ### Screenshot Summary

                From the dashboard shown in your screenshot:

                - **Revenue:** `$148,200` *(up **+24%** YoY)*
                - **Active Users:** `12,450`
                - **Quarter:** Q3 Performance

                #### Key Insights:
                1. Strong growth momentum in the final month shown in the bar chart.
                2. User activity correlates positively with the revenue spikes.
                """)
        }
    }
}
