import AppKit
import Foundation
import Observation
import ServiceManagement

/// Manages application auto-start on user login using modern SMAppService.mainApp.
@MainActor
@Observable
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    /// Reflects whether the app is currently configured to launch at login.
    var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            toggleLaunchAtLogin(enabled: newValue)
        }
    }

    /// The current system status of the main application login item.
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// Human-readable status description for UI displays.
    var statusDescription: String {
        switch status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval in System Settings > Login Items"
        case .notRegistered:
            return "Disabled"
        case .notFound:
            return "Not Available"
        @unknown default:
            return "Unknown"
        }
    }

    /// Error message from the last registration or unregistration attempt, if any.
    var errorMessage: String? = nil

    private init() {}

    /// Toggles the main application login item registration.
    func toggleLaunchAtLogin(enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Notice: SMAppService error: \(error)")
        }
    }

    /// Opens System Settings directly to General > Login Items & Extensions.
    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
