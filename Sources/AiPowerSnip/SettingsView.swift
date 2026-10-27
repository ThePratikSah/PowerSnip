import SwiftUI

/// The Settings window (Command-Comma). One tab per topic, at most about
/// six. Each tab is a grouped Form that sizes to its content, so the
/// window grows to fit and shows no scroll bar it does not need.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .appearance: AppearanceSettings()
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        }
    }
}

struct GeneralSettings: View {
    @AppStorage("api.baseURL") private var baseURL = "http://localhost:8080"
    @AppStorage("confirmDelete") private var confirmDelete = true

    var body: some View {
        Section("API") {
            TextField("Base URL", text: $baseURL)
                .textFieldStyle(.roundedBorder)
                .help("The base URL for the /analyse API endpoint")
            Text("The app sends screenshots to `\(baseURL)/analyse` for AI analysis.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("Screenshots") {
            Toggle("Ask before deleting screenshots", isOn: $confirmDelete)
        }
    }
}
