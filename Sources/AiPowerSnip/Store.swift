import Foundation

/// Handles disk persistence of screenshots and their chat history.
public enum Store {
    public static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    public static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            let directURL = URL(fileURLWithPath: path)
            // If path has an extension, use its containing directory
            if !directURL.pathExtension.isEmpty {
                let dir = directURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            }
            try? FileManager.default.createDirectory(at: directURL, withIntermediateDirectories: true)
            return directURL
        }
        let dir = URL.applicationSupportDirectory.appending(path: "Snip", directoryHint: .isDirectory)
        // Seamless migration from legacy AiPowerSnip directory if present
        let legacyDir = URL.applicationSupportDirectory.appending(path: "AiPowerSnip", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: dir.path) && FileManager.default.fileExists(atPath: legacyDir.path) {
            try? FileManager.default.copyItem(at: legacyDir, to: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func manifestURL(in directory: URL) -> URL {
        directory.appendingPathComponent("manifest.json")
    }

    public static func loadScreenshots(from directory: URL) -> [Screenshot] {
        let file = manifestURL(in: directory)
        guard let data = try? Data(contentsOf: file) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Screenshot].self, from: data)) ?? []
    }

    public static func saveScreenshots(_ screenshots: [Screenshot], to directory: URL) {
        let file = manifestURL(in: directory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(screenshots) else { return }
        try? data.write(to: file, options: [.atomic])
    }
}
