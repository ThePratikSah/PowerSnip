import AppKit

let width: CGFloat = 660
let height: CGFloat = 420
let scale: CGFloat = 2.0

let pixelWidth = Int(width * scale)
let pixelHeight = Int(height * scale)

let outputPath: String
if CommandLine.arguments.count > 1 {
    outputPath = CommandLine.arguments[1]
} else {
    outputPath = "background.png"
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: pixelWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

context.scaleBy(x: scale, y: scale)

let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext

// 1. Sleek, clean macOS gradient background
let bgGradient = NSGradient(
    starting: NSColor(red: 0.985, green: 0.988, blue: 0.995, alpha: 1.0),
    ending: NSColor(red: 0.925, green: 0.935, blue: 0.955, alpha: 1.0)
)!
bgGradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

// 2. Subtle decorative top accent glow
let topGlow = NSGradient(
    colors: [
        NSColor(red: 0.45, green: 0.40, blue: 0.95, alpha: 0.08),
        NSColor(red: 0.45, green: 0.40, blue: 0.95, alpha: 0.0)
    ]
)!
let glowPath = NSBezierPath(ovalIn: NSRect(x: width / 2 - 250, y: height - 120, width: 500, height: 200))
topGlow.draw(in: glowPath, angle: -90)

// 3. Drop target wells / subtle pedestals for the two icons
// Finder icon coordinates:
// Snip.app at (170, 200) from top-left => y_ns = 420 - 200 = 220
// Applications at (490, 200) from top-left => y_ns = 420 - 200 = 220
let leftCenter = CGPoint(x: 170, y: 220)
let rightCenter = CGPoint(x: 490, y: 220)

// Left pedestal (Source: Snip.app)
let leftPedestalRect = NSRect(x: leftCenter.x - 72, y: leftCenter.y - 78, width: 144, height: 144)
let leftPedestalPath = NSBezierPath(roundedRect: leftPedestalRect, xRadius: 20, yRadius: 20)
NSColor(white: 1.0, alpha: 0.65).setFill()
leftPedestalPath.fill()
NSColor(red: 0.85, green: 0.87, blue: 0.90, alpha: 0.7).setStroke()
leftPedestalPath.lineWidth = 1.0
leftPedestalPath.stroke()

// Right pedestal (Destination: Applications) - dashed drop well
let rightPedestalRect = NSRect(x: rightCenter.x - 72, y: rightCenter.y - 78, width: 144, height: 144)
let rightPedestalPath = NSBezierPath(roundedRect: rightPedestalRect, xRadius: 20, yRadius: 20)
NSColor(white: 1.0, alpha: 0.65).setFill()
rightPedestalPath.fill()
NSColor(red: 0.40, green: 0.45, blue: 0.95, alpha: 0.55).setStroke()
let dashPattern: [CGFloat] = [6.0, 4.0]
rightPedestalPath.setLineDash(dashPattern, count: 2, phase: 0)
rightPedestalPath.lineWidth = 1.5
rightPedestalPath.stroke()

// 4. Center visual arrow & "Drag to Install" badge
let arrowY = leftCenter.y + 10

// Directional arrow line
let arrowStart = CGPoint(x: 255, y: arrowY)
let arrowEnd = CGPoint(x: 405, y: arrowY)

let arrowPath = NSBezierPath()
arrowPath.move(to: arrowStart)
arrowPath.line(to: arrowEnd)
arrowPath.lineWidth = 2.5
arrowPath.setLineDash([5.0, 3.0], count: 2, phase: 0)
NSColor(red: 0.48, green: 0.52, blue: 0.88, alpha: 0.85).setStroke()
arrowPath.stroke()

// Arrow head
let headPath = NSBezierPath()
headPath.move(to: CGPoint(x: arrowEnd.x - 10, y: arrowY + 7))
headPath.line(to: CGPoint(x: arrowEnd.x + 2, y: arrowY))
headPath.line(to: CGPoint(x: arrowEnd.x - 10, y: arrowY - 7))
headPath.lineWidth = 2.5
headPath.lineCapStyle = .round
headPath.lineJoinStyle = .round
NSColor(red: 0.40, green: 0.42, blue: 0.92, alpha: 0.95).setStroke()
headPath.stroke()

// Pill badge in the middle: "Drag to Install"
let pillRect = NSRect(x: width / 2 - 64, y: arrowY + 14, width: 128, height: 26)
let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 13, yRadius: 13)

let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -2)
shadow.shadowBlurRadius = 6
shadow.shadowColor = NSColor(red: 0.40, green: 0.40, blue: 0.80, alpha: 0.25)
shadow.set()

let pillGradient = NSGradient(
    starting: NSColor(red: 0.38, green: 0.38, blue: 0.94, alpha: 1.0),
    ending: NSColor(red: 0.30, green: 0.30, blue: 0.86, alpha: 1.0)
)!
pillGradient.draw(in: pillPath, angle: -90)
NSShadow().set()

// Badge text
let badgeText = "Drag to Install" as NSString
let badgeAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor.white
]
let badgeSize = badgeText.size(withAttributes: badgeAttrs)
badgeText.draw(
    at: CGPoint(x: pillRect.midX - badgeSize.width / 2, y: pillRect.midY - badgeSize.height / 2 + 0.5),
    withAttributes: badgeAttrs
)

// 5. Title & Subtitle at Top
let titleText = "Install Snip" as NSString
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .bold),
    .foregroundColor: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
]
let titleSize = titleText.size(withAttributes: titleAttrs)
titleText.draw(at: CGPoint(x: width / 2 - titleSize.width / 2, y: height - 52), withAttributes: titleAttrs)

let subtitleText = "Drag Snip into Applications to complete installation" as NSString
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
    .foregroundColor: NSColor(red: 0.42, green: 0.46, blue: 0.52, alpha: 1.0)
]
let subtitleSize = subtitleText.size(withAttributes: subtitleAttrs)
subtitleText.draw(at: CGPoint(x: width / 2 - subtitleSize.width / 2, y: height - 74), withAttributes: subtitleAttrs)

// 6. Bottom hint text
let hintText = "Global Hotkey: ⌥⇧⌘4  •  Protected Screen Capture  •  Gemini AI Multimodal" as NSString
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
    .foregroundColor: NSColor(red: 0.55, green: 0.58, blue: 0.65, alpha: 1.0)
]
let hintSize = hintText.size(withAttributes: hintAttrs)
hintText.draw(at: CGPoint(x: width / 2 - hintSize.width / 2, y: 24), withAttributes: hintAttrs)

// 7. Render and write PNG
guard let cgImage = context.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: width, height: height)
guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError("pngData failed") }
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated DMG background image at: \(outputPath)")
