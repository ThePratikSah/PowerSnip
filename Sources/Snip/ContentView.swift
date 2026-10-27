import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Bindable private var permissionManager = ScreenCapturePermissionManager.shared

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ScreenshotDetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .top) {
            if !permissionManager.isGranted {
                permissionMissingBanner
            }
        }
        .sheet(isPresented: $permissionManager.showPermissionPrompt) {
            ScreenRecordingPermissionSheet()
        }
        .task {
            SeedData.insertIfRequested(into: model)
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
            permissionManager.checkPermission()
        }
    }

    private var permissionMissingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .foregroundStyle(.orange)
                .font(.headline)

            VStack(alignment: .leading, spacing: 1) {
                Text("Screen Recording Permission Required")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text("Snip needs Screen Recording permission to capture sections of your screen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Grant Access") {
                permissionManager.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Dismiss") {
                permissionManager.showPermissionPrompt = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.orange.opacity(0.3)), alignment: .bottom)
    }

    private var sidebar: some View {
        @Bindable var model = model
        return ScreenshotListView()
            .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 360)
    }
}

// MARK: - Sidebar: Screenshot List

struct ScreenshotListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Top inset for window traffic light dots
            Color.clear.frame(height: 32)

            List(model.screenshots, selection: $model.selection) { screenshot in
                ScreenshotRowView(screenshot: screenshot)
                    .tag(screenshot.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            model.deleteScreenshot(screenshot)
                        }
                    }
            }
            .listStyle(.sidebar)
            .overlay {
                if model.screenshots.isEmpty {
                    ContentUnavailableView(
                        "No Screenshots",
                        systemImage: "camera.viewfinder",
                        description: Text("Press ⌥⇧⌘4 to snip any section of the screen.")
                    )
                }
            }

            Divider()

            // Bottom action bar
            HStack(spacing: 8) {
                Button(action: {
                    Task { await ScreenCapture.captureSelection(model: model) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                        Text("Snip (⌥⇧⌘4)")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(model.isCapturing)

                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Settings (⌘,)")
            }
            .padding(10)
        }
    }
}

struct ScreenshotRowView: View {
    @Environment(AppModel.self) private var model
    let screenshot: Screenshot

    var body: some View {
        HStack(spacing: 10) {
            if let image = screenshot.loadImage(from: model.storeDirectory) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 48, height: 34)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(screenshot.createdAt, style: .time)
                    if !screenshot.messages.isEmpty {
                        Text("•")
                        Label("\(screenshot.messages.count)", systemImage: "bubble.left.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detail View

struct ScreenshotDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let screenshot = model.selectedScreenshot {
            ActiveScreenshotCanvas(screenshot: screenshot)
        } else {
            ContentUnavailableView(
                "No Screenshot Selected",
                systemImage: "photo.badge.plus",
                description: Text("Press ⌥⇧⌘4 to snip a section of your screen.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ActiveScreenshotCanvas: View {
    @Environment(AppModel.self) private var model
    @Bindable var screenshot: Screenshot
    @State private var isChatVisible: Bool = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Screenshot Image Area
            screenshotDisplay
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Sleek floating controls (headerless layout)
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        isChatVisible.toggle()
                    }
                }) {
                    Label(isChatVisible ? "Hide Chat" : "Ask Gemini",
                          systemImage: isChatVisible ? "bubble.right.fill" : "sparkles")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(role: .destructive, action: {
                    model.deleteScreenshot(screenshot)
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Delete screenshot")
            }
            .padding(.top, 16)
            .padding(.trailing, 16)

            // Small AI Analysis Chat Overlay Box - Forced Light Mode
            if isChatVisible {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ChatOverlayBox(screenshot: screenshot)
                            .frame(width: 420, height: 520)
                            .padding(Space.lg)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                    }
                }
            }
        }
    }

    private var screenshotDisplay: some View {
        GeometryReader { proxy in
            if let image = screenshot.loadImage(from: model.storeDirectory) {
                ScrollView([.horizontal, .vertical]) {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
                                .padding(Space.lg)
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            } else {
                ContentUnavailableView(
                    "Image Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Could not read screenshot file.")
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Small AI Chat Box Overlay (FORCED LIGHT MODE)

struct ChatOverlayBox: View {
    @Environment(AppModel.self) private var model
    @Bindable var screenshot: Screenshot
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
            // Header
            chatHeader
            Divider().background(Color(hex: 0xE5E7EB))

            // API key missing banner
            if !GeminiService.hasAPIKey {
                apiKeyWarningBanner
                Divider().background(Color(hex: 0xE5E7EB))
            }

            // Message Scroll Stream
            chatHistory
            Divider().background(Color(hex: 0xE5E7EB))

            // Quick suggestion chips (if conversation is fresh)
            if screenshot.messages.isEmpty {
                suggestionChips
                Divider().background(Color(hex: 0xE5E7EB))
            }

            // Input bar
            chatInputBar
        }
        // FORCED 100% LIGHT MODE WITH SOLID WHITE BACKGROUND (NO DARK TINT FROM SCREENSHOT)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xE2E8F0), lineWidth: 1)
        )
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
                    if let models = try? await GeminiService.getMultimodalModels(), !models.isEmpty {
                        availableModels = models
                    }
                }
            }
        }
    }

    private var chatHeader: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Gemini Snip Assistant")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x111827))
                Text("Ask anything about this screenshot")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: 0x6B7280))
            }

            Spacer()

            // Dynamic Model Switcher Menu in header
            Menu {
                ForEach(availableModels) { m in
                    Button(action: {
                        selectedModel = m.shortName
                        GeminiService.model = m.shortName
                    }) {
                        HStack {
                            Text(m.displayName)
                            if m.shortName == selectedModel || m.name == selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text(selectedModel.replacingOccurrences(of: "models/", with: ""))
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Color(hex: 0x374151))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: 0xF3F4F6), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Switch Gemini AI Model")

            // API Key status/config button
            Button(action: { showAPIKeySheet = true }) {
                HStack(spacing: 3) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(GeminiService.hasAPIKey ? Color.green : Color.orange)
                    if !GeminiService.hasAPIKey {
                        Text("Add Key")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    (GeminiService.hasAPIKey ? Color.green : Color.orange).opacity(0.12),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .help(GeminiService.hasAPIKey ? "Configure Gemini API Key" : "Set Gemini API Key to enable AI analysis")

            if !screenshot.messages.isEmpty {
                Button(action: {
                    model.clearMessages(for: screenshot)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x9CA3AF))
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    private var apiKeyWarningBanner: some View {
        Button(action: { showAPIKeySheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gemini API Key Required")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x1F2937))
                    Text("Click here to paste your free Google Gemini API key.")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: 0x4B5563))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
                            ChatMessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }

                    if isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking with \(selectedModel.replacingOccurrences(of: "models/", with: ""))…")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: 0x4B5563))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0xF3F4F6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .id("analyzing_spinner")
                    }

                    // Intuitive Rate Limit & API Error Resolution Card with Model Switcher
                    if let error = currentError {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: error.isRateLimit ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                                    .foregroundStyle(error.isRateLimit ? .orange : .red)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(error.isRateLimit ? "Rate Limit Exceeded (429)" : "API Request Failed")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(error.isRateLimit ? Color(hex: 0x9A3412) : Color(hex: 0x991B1B))

                                    Text(error.isRateLimit
                                         ? "The model '\(selectedModel.replacingOccurrences(of: "models/", with: ""))' reached its quota or request rate limit. Switch to an alternate model below to continue immediately."
                                         : (error.errorDescription ?? "An error occurred while contacting the Gemini API."))
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: 0x374151))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Button(action: { currentError = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: 0x6B7280))
                                }
                                .buttonStyle(.plain)
                            }

                            // Model switcher dropdown inside the error resolution card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Switch Model:")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color(hex: 0x4B5563))

                                Picker("Switch Model", selection: $selectedModel) {
                                    ForEach(availableModels) { m in
                                        Text(m.displayName).tag(m.shortName)
                                    }
                                }
                                .labelsHidden()
                                .onChange(of: selectedModel) { _, newModel in
                                    GeminiService.model = newModel
                                }
                            }

                            // Action buttons: Retry and Dismiss
                            HStack(spacing: 8) {
                                if let _ = lastFailedQuery {
                                    Button(action: {
                                        retryFailedQuery()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Retry with \(selectedModel.replacingOccurrences(of: "models/", with: ""))")
                                        }
                                        .font(.caption.weight(.medium))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }

                                Button("Dismiss") {
                                    currentError = nil
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.top, 2)
                        }
                        .padding(12)
                        .background(
                            (error.isRateLimit ? Color.orange : Color.red).opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke((error.isRateLimit ? Color.orange : Color.red).opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal, 4)
                        .id("error_resolution_card")
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
            .onChange(of: isAnalyzing) {
                if isAnalyzing {
                    withAnimation { proxy.scrollTo("analyzing_spinner", anchor: .bottom) }
                }
            }
            .onChange(of: currentError != nil) {
                if currentError != nil {
                    withAnimation { proxy.scrollTo("error_resolution_card", anchor: .bottom) }
                }
            }
        }
    }

    private var emptyPromptView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Palette.accent.opacity(0.8))
                .padding(.top, 12)

            Text("Ask Gemini about this screen")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(hex: 0x111827))

            Text("Type any question below or pick a suggestion to analyze text, layout, UI code, or data.")
                .font(.caption)
                .foregroundStyle(Color(hex: 0x6B7280))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                suggestionButton("Summarize text")
                suggestionButton("Explain UI layout")
                suggestionButton("Find bugs or issues")
                suggestionButton("Extract key data")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.white)
    }

    private func suggestionButton(_ text: String) -> some View {
        Button(action: {
            inputPrompt = text
            triggerSend()
        }) {
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color(hex: 0x374151))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: 0xF3F4F6), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0xE5E7EB), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about screenshot…", text: $inputPrompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .font(.callout)
                .foregroundStyle(Color(hex: 0x111827))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: 0xF3F4F6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0xE5E7EB), lineWidth: 1)
                )
                .onSubmit { triggerSend() }

            Button(action: triggerSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Palette.accent : Color(hex: 0xD1D5DB))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(10)
        .background(Color.white)
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

        // Add user query message
        model.addMessage(to: screenshot, role: .user, content: text)

        guard let data = screenshot.loadData(from: model.storeDirectory) else {
            currentError = .apiError(statusCode: 0, message: "Could not load screenshot data from disk.")
            isAnalyzing = false
            return
        }

        Task {
            do {
                let markdownResponse = try await GeminiService.generateAnalysis(
                    imageData: data,
                    query: text
                )
                model.addMessage(to: screenshot, role: .assistant, content: markdownResponse)
                lastFailedQuery = nil
            } catch let geminiErr as GeminiError {
                currentError = geminiErr
                if case .invalidAPIKey = geminiErr {
                    showAPIKeySheet = true
                }
            } catch {
                currentError = .apiError(statusCode: 0, message: error.localizedDescription)
            }
            isAnalyzing = false
        }
    }

    private func retryFailedQuery() {
        guard let query = lastFailedQuery, !isAnalyzing else { return }
        currentError = nil
        isAnalyzing = true

        guard let data = screenshot.loadData(from: model.storeDirectory) else {
            currentError = .apiError(statusCode: 0, message: "Could not load screenshot data from disk.")
            isAnalyzing = false
            return
        }

        Task {
            do {
                let markdownResponse = try await GeminiService.generateAnalysis(
                    imageData: data,
                    query: query
                )
                model.addMessage(to: screenshot, role: .assistant, content: markdownResponse)
                lastFailedQuery = nil
            } catch let geminiErr as GeminiError {
                currentError = geminiErr
                if case .invalidAPIKey = geminiErr {
                    showAPIKeySheet = true
                }
            } catch {
                currentError = .apiError(statusCode: 0, message: error.localizedDescription)
            }
            isAnalyzing = false
        }
    }
}

// MARK: - Chat Message Bubble (FORCED LIGHT MODE)

struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    MarkdownRendererView(markdown: message.content)
                } else {
                    Text(message.content)
                        .font(.callout)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(message.role == .assistant ? 0.04 : 0.0), radius: 2, y: 1)

            if message.role == .assistant {
                Spacer(minLength: 16)
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Palette.accent)
        } else {
            // Pure white card on light gray background
            return AnyShapeStyle(Color.white)
        }
    }

    private var borderColor: Color {
        if message.role == .user {
            return Color.clear
        } else {
            return Color(hex: 0xE5E7EB)
        }
    }
}
