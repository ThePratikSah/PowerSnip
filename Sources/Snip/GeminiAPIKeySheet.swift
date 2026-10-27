import SwiftUI

/// Modal sheet for entering the Google Gemini API key and selecting from official, active multimodal models.
struct GeminiAPIKeySheet: View {
    @Binding var isPresented: Bool
    @State private var inputKey: String = ""
    @State private var selectedModel: String = GeminiService.model
    @State private var models: [GeminiService.ModelInfo] = GeminiService.officialModels
    @State private var isLoadingModels: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isSuccessStatus: Bool = false
    @State private var showKeyText: Bool = false
    var onSaved: (() -> Void)? = nil

    private var selectedModelInfo: GeminiService.ModelInfo? {
        models.first { $0.shortName == selectedModel || $0.name == selectedModel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 44, height: 44)
                    .background(Palette.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Gemini API Setup")
                        .font(.headline)
                    Text("Connect your API key to enable multimodal AI screenshot analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            // Key Input Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Google Gemini API Key")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    if showKeyText {
                        TextField("Paste API key (AIzaSy...)", text: $inputKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("Paste API key (AIzaSy...)", text: $inputKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button(action: { showKeyText.toggle() }) {
                        Image(systemName: showKeyText ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showKeyText ? "Hide API key" : "Show API key")

                    Button(action: { Task { await fetchModels() } }) {
                        HStack(spacing: 4) {
                            if isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Fetch Models")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingModels)
                    .help("Query Google Gemini API for live official models")
                }

                // Privacy statement
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Your API key is stored locally on your Mac and is not sent anywhere except directly to the official Google Gemini API.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            // Model Selection Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Official Gemini Model")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    if let status = statusMessage {
                        HStack(spacing: 4) {
                            Image(systemName: isSuccessStatus ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text(status)
                                .font(.caption2)
                        }
                        .foregroundStyle(isSuccessStatus ? .green : .orange)
                    }
                }

                Picker("", selection: $selectedModel) {
                    ForEach(models) { model in
                        Text(model.displayName)
                            .tag(model.shortName)
                    }
                }
                .labelsHidden()

                // Selected model information card
                if let info = selectedModelInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.description)
                            .font(.caption)
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            if let inLimit = info.inputTokenLimit {
                                Text("Context: \(formatTokens(inLimit)) tokens")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let outLimit = info.outputTokenLimit {
                                Text("Max Output: \(formatTokens(outLimit)) tokens")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("• Official Active Model")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            // AI Studio Link
            HStack {
                Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                    HStack(spacing: 4) {
                        Text("Get a free API key at Google AI Studio")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption)
                }
                Spacer()
            }

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save API Key") {
                    saveKey()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear {
            inputKey = GeminiService.apiKey
            selectedModel = GeminiService.model
            if !inputKey.isEmpty {
                Task {
                    await fetchModels()
                }
            }
        }
    }

    private func fetchModels() async {
        let trimmedKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        isLoadingModels = true
        statusMessage = "Discovering official models..."
        isSuccessStatus = true

        do {
            let discovered = try await GeminiService.getMultimodalModels(customApiKey: trimmedKey)
            if !discovered.isEmpty {
                models = discovered
                // If currently selected model is in list, keep it, otherwise choose the first one
                let shortNames = Set(discovered.map(\.shortName))
                let fullNames = Set(discovered.map(\.name))
                if !shortNames.contains(selectedModel) && !fullNames.contains(selectedModel) {
                    selectedModel = discovered.first?.shortName ?? "gemini-2.5-flash"
                }
                statusMessage = "Loaded \(discovered.count) official models"
                isSuccessStatus = true
            } else {
                models = GeminiService.officialModels
                statusMessage = "Using curated official models"
                isSuccessStatus = true
            }
        } catch {
            models = GeminiService.officialModels
            statusMessage = "Offline fallback: official models"
            isSuccessStatus = false
        }

        isLoadingModels = false
    }

    private func saveKey() {
        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        GeminiService.apiKey = trimmed
        GeminiService.model = selectedModel
        isPresented = false
        onSaved?()
    }

    private func formatTokens(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
