import SwiftUI

/// Modal sheet for entering or updating the user's Google Gemini API key.
struct GeminiAPIKeySheet: View {
    @Binding var isPresented: Bool
    @State private var inputKey: String = ""
    @State private var selectedModel: String = GeminiService.model
    var onSaved: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 44, height: 44)
                    .background(Palette.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enter Gemini API Key")
                        .font(.headline)
                    Text("Connect to Google Gemini for AI screenshot analysis")
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

                SecureField("Paste your API key (starts with AIzaSy...)", text: $inputKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                // Local storage privacy statement
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

            // Model selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Gemini Model")
                    .font(.subheadline.weight(.medium))

                Picker("", selection: $selectedModel) {
                    ForEach(GeminiService.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.segmented)
            }

            // AI Studio link
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
        .frame(width: 480)
        .onAppear {
            inputKey = GeminiService.apiKey
            selectedModel = GeminiService.model
        }
    }

    private func saveKey() {
        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        GeminiService.apiKey = trimmed
        GeminiService.model = selectedModel
        isPresented = false
        onSaved?()
    }
}
