import SwiftUI

/// The Settings window (Command-Comma). One tab per topic.
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
        .frame(width: 540)
    }
}

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
    @AppStorage("gemini.apiKey") private var apiKey = ""
    @AppStorage("gemini.model") private var selectedModel = "gemini-2.5-flash"
    @AppStorage("confirmDelete") private var confirmDelete = true
    @State private var showKey = false
    @State private var models: [GeminiService.ModelInfo] = GeminiService.officialModels
    @State private var isLoadingModels = false

    var body: some View {
        Section("Google Gemini API") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showKey ? "Hide API key" : "Show API key")

                    Button(action: { Task { await refreshModels() } }) {
                        if isLoadingModels {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Fetch official models from Gemini API")
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingModels)
                }

                Picker("Official Model", selection: $selectedModel) {
                    ForEach(models) { m in
                        Text(m.displayName).tag(m.shortName)
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Your API key is stored locally on your Mac and is not sent anywhere except directly to the official Google Gemini API.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                    HStack(spacing: 4) {
                        Text("Get a free Gemini API Key at Google AI Studio")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption)
                }
            }
        }
        .task {
            if !apiKey.isEmpty {
                await refreshModels()
            }
        }

        Section("Screenshots") {
            Toggle("Ask before deleting screenshots", isOn: $confirmDelete)
        }

        Section("Storage & Privacy") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chat and screenshot data are stored locally in:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("~/Library/Application Support/AiPowerSnip/")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func refreshModels() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingModels = true
        do {
            let discovered = try await GeminiService.getMultimodalModels(customApiKey: trimmed)
            if !discovered.isEmpty {
                models = discovered
            }
        } catch {
            // Keep existing or fallback
        }
        isLoadingModels = false
    }
}
