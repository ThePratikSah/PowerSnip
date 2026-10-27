import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: make_icon.swift <repo_dir>")
    exit(1)
}

let repo = URL(fileURLWithPath: CommandLine.arguments[1])
let resourcesDir = repo.appendingPathComponent("Resources")
try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let iconset = repo.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

for (pt, scale) in sizes {
    let px = pt * scale
    let img = NSImage(size: NSSize(width: px, height: px), flipped: false) { rect in
        let radius = CGFloat(px) * 0.22
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(px) * 0.05, dy: CGFloat(px) * 0.05), xRadius: radius, yRadius: radius)
        
        let grad = NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.52, blue: 0.98, alpha: 1),
                              ending: NSColor(srgbRed: 0.48, green: 0.22, blue: 0.88, alpha: 1))
        grad?.draw(in: path, angle: -45)
        
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(px) * 0.45, weight: .semibold)
        if let symbol = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
            let symbolSize = symbol.size
            let origin = NSPoint(x: (rect.width - symbolSize.width) / 2, y: (rect.height - symbolSize.height) / 2)
            symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        return true
    }
    
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        try? png.write(to: iconset.appendingPathComponent(name))
    }
}

let icnsURL = repo.appendingPathComponent("Resources/AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", icnsURL.path]
try? proc.run()
proc.waitUntilExit()

try? FileManager.default.removeItem(at: iconset)

// Touch Assets.car for build script compatibility
let carURL = repo.appendingPathComponent("Resources/Assets.car")
if !FileManager.default.fileExists(atPath: carURL.path) {
    try? Data().write(to: carURL)
}

print("Generated AppIcon.icns")
