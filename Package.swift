// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Snip",
    platforms: [.macOS(.v15)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "SnipKit"),
        .executableTarget(
            name: "Snip",
            dependencies: ["SnipKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "SnipKitTests", dependencies: ["SnipKit"]),
    ]
)
