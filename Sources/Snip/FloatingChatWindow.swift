import AppKit
import SwiftUI

/// A non-activating floating NSPanel that shows the compact chat HUD after a snip.
final class FloatingChatWindow: NSPanel {
    private var hostingController: NSHostingController<AnyView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false

        // Protect from screen capture tools
        self.sharingType = .none

        // Initial minimum/maximum sizes
        self.minSize = NSSize(width: 380, height: 480)
        self.maxSize = NSSize(width: 560, height: 800)

        // Center on screen on first show
        self.center()

        setupContent()
    }

    private func setupContent() {
        let view = FloatingChatView()
        let hosting = NSHostingController(rootView: AnyView(view))
        self.hostingController = hosting
        self.contentViewController = hosting
    }

    func updateScreenshot(id: UUID) {
        // The view reads from WindowManager.shared.activeScreenshotId and AppModel.shared
        // so just re-ordering triggers a refresh via @Observable
        _ = id
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The SwiftUI view hosted inside FloatingChatWindow.
struct FloatingChatView: View {
    @State private var model: AppModel? = AppModel.shared

    var body: some View {
        Group {
            if let model, let id = WindowManager.shared.activeScreenshotId,
                let screenshot = model.screenshots.first(where: { $0.id == id })
            {
                FloatingChatContent(screenshot: screenshot, model: model)
            } else {
                waitingView
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)
        ) { _ in
            model = AppModel.shared
        }
    }

    private var waitingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Waiting for a snip…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

/// Full chat content inside the floating panel.
struct FloatingChatContent: View {
    @Bindable var screenshot: Screenshot
    var model: AppModel

    @State private var inputPrompt: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var currentError: GeminiError? = nil
    @State private var lastFailedQuery: String? = nil
    @State private var selectedModel: String = GeminiService.model
    @State private var availableModels: [GeminiService.ModelInfo] = GeminiService.officialModels
    @State private var showAPIKeySheet: Bool = false
    @State private var pendingQuery: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            floatingHeader
            Divider()

            if !GeminiService.hasAPIKey {
                apiKeyWarningBanner
                Divider()
            }

            chatHistory
            Divider()

            if screenshot.messages.isEmpty {
                suggestionChips
                Divider()
            }

            chatInputBar
        }
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showAPIKeySheet) {
            GeminiAPIKeySheet(isPresented: $showAPIKeySheet) {
                if let query = pendingQuery {
                    pendingQuery = nil
                    sendQuery(text: query)
                }
            }
        }
        .onAppear {
            selectedModel = GeminiService.model
            if GeminiService.hasAPIKey {
                Task {
                    if let models = try? await GeminiService.getMultimodalModels(), !models.isEmpty
                    {
                        availableModels = models
                    }
                }
            }
        }
    }

    private var floatingHeader: some View {
        HStack(spacing: 8) {
            // Thumbnail
            if let image = screenshot.loadImage(from: model.storeDirectory) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(
                            Color.black.opacity(0.1), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                    Text("Gemini Snip Assistant")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x111827))
                }
                if screenshot.isGeneratingTitle {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("Analyzing…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(screenshot.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Model picker
            Menu {
                ForEach(availableModels) { m in
                    Button(action: {
                        selectedModel = m.shortName
                        GeminiService.model = m.shortName
                    }) {
                        HStack {
                            Text(m.displayName)
                            if m.shortName == selectedModel { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "cpu").font(.system(size: 9))
                    Text(selectedModel.replacingOccurrences(of: "models/", with: "")).font(
                        .system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                }
                .foregroundStyle(Color(hex: 0x374151))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color(hex: 0xF3F4F6), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Expand to main window
            Button(action: { WindowManager.shared.expandToMainWindow() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand to Full App")

            // API key button
            Button(action: { showAPIKeySheet = true }) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(GeminiService.hasAPIKey ? .green : .orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white)
    }

    private var apiKeyWarningBanner: some View {
        Button(action: { showAPIKeySheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange).font(
                    .subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gemini API Key Required").font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x1F2937))
                    Text("Click here to paste your free Google Gemini API key.").font(.caption2)
                        .foregroundStyle(Color(hex: 0x4B5563))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.orange.opacity(0.08))
        }
        .buttonStyle(.plain)
    }

    private var chatHistory: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if screenshot.messages.isEmpty {
                        emptyPromptView
                    } else {
                        ForEach(screenshot.messages) { msg in
                            ChatMessageBubble(message: msg).id(msg.id)
                        }
                    }
                    if isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Thinking…").font(.caption.weight(.medium)).foregroundStyle(
                                Color(hex: 0x4B5563))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            Color(hex: 0xF3F4F6),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .id("analyzing_spinner")
                    }
                    if let error = currentError {
                        errorCard(error: error)
                    }
                }
                .padding(12)
            }
            .background(Color(hex: 0xFAFAFA))
            .onChange(of: screenshot.messages.count) {
                if let lastID = screenshot.messages.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
        }
    }

    private func errorCard(error: GeminiError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(
                    systemName: error.isRateLimit
                        ? "exclamationmark.triangle.fill" : "xmark.octagon.fill"
                )
                .foregroundStyle(error.isRateLimit ? .orange : .red).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.isRateLimit ? "Rate Limit Exceeded" : "API Error")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(
                            error.isRateLimit ? Color(hex: 0x9A3412) : Color(hex: 0x991B1B))
                    Text(error.errorDescription ?? "An error occurred.").font(.caption2)
                        .foregroundStyle(Color(hex: 0x374151)).fixedSize(
                            horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: { currentError = nil }) {
                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            Picker("Switch Model", selection: $selectedModel) {
                ForEach(availableModels) { m in Text(m.displayName).tag(m.shortName) }
            }
            .labelsHidden()
            .onChange(of: selectedModel) { _, v in GeminiService.model = v }
            HStack(spacing: 8) {
                if lastFailedQuery != nil {
                    Button(action: retryFailedQuery) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.caption.weight(.medium))
                    }.buttonStyle(.borderedProminent).controlSize(.small)
                }
                Button("Dismiss") { currentError = nil }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(12)
        .background(
            (error.isRateLimit ? Color.orange : Color.red).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(
                (error.isRateLimit ? Color.orange : Color.red).opacity(0.25), lineWidth: 1))
    }

    private var emptyPromptView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 32)).foregroundStyle(
                .purple.opacity(0.8)
            ).padding(.top, 12)
            Text("Ask Gemini about this screen").font(.callout.weight(.semibold)).foregroundStyle(
                Color(hex: 0x111827))
            Text("Type any question or pick a suggestion below.").font(.caption).foregroundStyle(
                .secondary
            ).multilineTextAlignment(.center).padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("Summarize text")
                chip("Explain UI layout")
                chip("Find bugs or issues")
                chip("Extract key data")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color.white)
    }

    private func chip(_ text: String) -> some View {
        Button(action: {
            inputPrompt = text
            triggerSend()
        }) {
            Text(text).font(.caption2.weight(.medium)).foregroundStyle(Color(hex: 0x374151))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color(hex: 0xF3F4F6), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about screenshot…", text: $inputPrompt, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...4).font(.callout)
                .foregroundStyle(Color(hex: 0x111827))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    Color(hex: 0xF3F4F6), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(
                        Color(hex: 0xE5E7EB), lineWidth: 1)
                )
                .onSubmit { triggerSend() }
            Button(action: triggerSend) {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
                    .foregroundStyle(canSend ? Color.purple : Color(hex: 0xD1D5DB))
            }
            .buttonStyle(.plain).disabled(!canSend)
        }
        .padding(10).background(Color.white)
    }

    private var canSend: Bool {
        !inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    private func triggerSend() {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnalyzing else { return }
        if !GeminiService.hasAPIKey {
            pendingQuery = trimmed
            showAPIKeySheet = true
            return
        }
        sendQuery(text: trimmed)
    }

    private func sendQuery(text: String) {
        inputPrompt = ""
        currentError = nil
        isAnalyzing = true
        lastFailedQuery = text
        model.addMessage(to: screenshot, role: .user, content: text)
        guard let data = screenshot.loadData(from: model.storeDirectory) else {
            currentError = .apiError(statusCode: 0, message: "Could not load screenshot data.")
            isAnalyzing = false
            return
        }
        Task {
            do {
                let resp = try await GeminiService.generateAnalysis(imageData: data, query: text)
                model.addMessage(to: screenshot, role: .assistant, content: resp)
                lastFailedQuery = nil
            } catch let e as GeminiError {
                currentError = e
                if case .invalidAPIKey = e { showAPIKeySheet = true }
            } catch { currentError = .apiError(statusCode: 0, message: error.localizedDescription) }
            isAnalyzing = false
        }
    }

    private func retryFailedQuery() {
        guard let query = lastFailedQuery, !isAnalyzing else { return }
        currentError = nil
        isAnalyzing = true
        guard let data = screenshot.loadData(from: model.storeDirectory) else {
            currentError = .apiError(statusCode: 0, message: "Could not load screenshot data.")
            isAnalyzing = false
            return
        }
        Task {
            do {
                let resp = try await GeminiService.generateAnalysis(imageData: data, query: query)
                model.addMessage(to: screenshot, role: .assistant, content: resp)
                lastFailedQuery = nil
            } catch let e as GeminiError { currentError = e } catch {
                currentError = .apiError(statusCode: 0, message: error.localizedDescription)
            }
            isAnalyzing = false
        }
    }
}
