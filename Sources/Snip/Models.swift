import AppKit
import Foundation
import Observation
import SnipKit

/// A single message exchanged in the screenshot chat.
public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    public var id: UUID
    public var role: Role
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

/// A captured screenshot with its question & answer chat history.
@Observable
public final class Screenshot: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var imageFileName: String
    public var messages: [ChatMessage]
    /// Transient flag — true while TitleGenerator is running. Not persisted to JSON.
    public var isGeneratingTitle: Bool = false

    public enum CodingKeys: String, CodingKey {
        case id, title, createdAt, imageFileName, messages
    }

    public init(id: UUID = UUID(), title: String, createdAt: Date = Date(), imageFileName: String, messages: [ChatMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.messages = messages
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.imageFileName = try container.decode(String.self, forKey: .imageFileName)
        self.messages = try container.decode([ChatMessage].self, forKey: .messages)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(imageFileName, forKey: .imageFileName)
        try container.encode(messages, forKey: .messages)
    }

    public static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        lhs.id == rhs.id
    }

    /// Load the image data from disk.
    public func loadData(from directory: URL) -> Data? {
        let fileURL = directory.appendingPathComponent(imageFileName)
        return try? Data(contentsOf: fileURL)
    }

    /// Load the NSImage from disk.
    public func loadImage(from directory: URL) -> NSImage? {
        guard let data = loadData(from: directory) else { return nil }
        return NSImage(data: data)
    }
}

/// Sidebar items.
public enum SidebarItem: String, CaseIterable, Identifiable {
    case all
    case recent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "All Screenshots"
        case .recent: "Recent"
        }
    }

    public var symbol: String {
        switch self {
        case .all: "photo.stack"
        case .recent: "clock"
        }
    }
}

/// App-wide state that views, menus, and services share.
@Observable
final class AppModel {
    static var shared: AppModel?

    var screenshots: [Screenshot] = []
    var selection: UUID?
    var sidebar: SidebarItem? = .all
    var isCapturing: Bool = false
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet {
            if !Store.isOverridden {
                UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab")
            }
        }
    }

    var storeDirectory: URL

    init(storeDirectory: URL = Store.url) {
        self.storeDirectory = storeDirectory
        self.screenshots = Store.loadScreenshots(from: storeDirectory)
        self.selection = self.screenshots.first?.id
        AppModel.shared = self
    }

    var selectedScreenshot: Screenshot? {
        screenshots.first { $0.id == selection }
    }

    func addScreenshot(imageData: Data, title: String = "") {
        let id = UUID()
        let cleanTitle = title.isEmpty ? "Screenshot \(DateFormatter.shortFormat.string(from: .now))" : ItemTitle.clean(title)
        let fileName = "\(id.uuidString).png"
        let fileURL = storeDirectory.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)
        } catch {
            print("Failed to write screenshot image: \(error)")
        }

        let screenshot = Screenshot(id: id, title: cleanTitle, imageFileName: fileName)
        screenshots.insert(screenshot, at: 0)
        selection = screenshot.id
        save()
    }

    func deleteScreenshot(_ screenshot: Screenshot) {
        // Delete image file
        let fileURL = storeDirectory.appendingPathComponent(screenshot.imageFileName)
        try? FileManager.default.removeItem(at: fileURL)

        screenshots.removeAll { $0.id == screenshot.id }
        if selection == screenshot.id {
            selection = screenshots.first?.id
        }
        save()
    }

    func addMessage(to screenshot: Screenshot, role: ChatMessage.Role, content: String) {
        let message = ChatMessage(role: role, content: content)
        screenshot.messages.append(message)
        save()
    }

    func clearMessages(for screenshot: Screenshot) {
        screenshot.messages.removeAll()
        save()
    }

    func updateTitle(for screenshot: Screenshot, title: String) {
        screenshot.title = title
        screenshot.isGeneratingTitle = false
        save()
    }

    func save() {
        Store.saveScreenshots(screenshots, to: storeDirectory)
    }
}

extension DateFormatter {
    public static let shortFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()
}
