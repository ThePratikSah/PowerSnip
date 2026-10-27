import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ScreenshotDetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            SeedData.insertIfRequested(into: model)
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
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

    var body: some View {
        @Bindable var model = model
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
                    description: Text("Press ⌥⇧⌘4 or ⇧⌘4 to snip any section of the screen.")
                )
            }
        }
        .navigationTitle("Screenshots")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        Task { await ScreenCapture.captureSelection(model: model) }
                    }) {
                        Label("Snip Section (⌥⇧⌘4 / ⇧⌘4)", systemImage: "crop")
                    }
                    .keyboardShortcut("4", modifiers: [.command, .option, .shift])

                    Button(action: {
                        Task { await ScreenCapture.captureFullScreen(model: model) }
                    }) {
                        Label("Capture Full Screen (⇧⌘3)", systemImage: "macwindow")
                    }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                } label: {
                    Label("Snip Section", systemImage: "camera.viewfinder")
                } primaryAction: {
                    Task { await ScreenCapture.captureSelection(model: model) }
                }
                .help("Snip a section of the screen (⌥⇧⌘4 / ⇧⌘4)")
                .disabled(model.isCapturing)
            }
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
        ZStack(alignment: .bottomTrailing) {
            // Main Screenshot Image Area
            screenshotDisplay
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Small AI Analysis Chat Overlay Box
            if isChatVisible {
                ChatOverlayBox(screenshot: screenshot)
                    .frame(width: 420, height: 520)
                    .padding(Space.lg)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        isChatVisible.toggle()
                    }
                }) {
                    Label(isChatVisible ? "Hide Chat" : "Ask AI",
                          systemImage: isChatVisible ? "bubble.right.fill" : "sparkles")
                }
                .help(isChatVisible ? "Hide question box" : "Show question box")
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(action: {
                    model.deleteScreenshot(screenshot)
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete screenshot")
            }
        }
        .navigationTitle(screenshot.title)
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

// MARK: - Small AI Chat Box Overlay

struct ChatOverlayBox: View {
    @Environment(AppModel.self) private var model
    @Bindable var screenshot: Screenshot
    @State private var inputPrompt: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var errorText: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            Divider()

            // Message Scroll Stream
            chatHistory
            Divider()

            // Quick suggestion chips (if conversation is fresh)
            if screenshot.messages.isEmpty {
                suggestionChips
                Divider()
            }

            // Input bar
            chatInputBar
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 8)
    }

    private var chatHeader: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(Palette.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("AI Snip Assistant")
                    .font(.subheadline.weight(.semibold))
                Text("Ask anything about this screenshot")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !screenshot.messages.isEmpty {
                Button(action: {
                    model.clearMessages(for: screenshot)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
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
                            Text("Analyzing screenshot with `/analyse`…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .id("analyzing_spinner")
                    }

                    if let error = errorText {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(12)
            }
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
        }
    }

    private var emptyPromptView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.top, 12)

            Text("What would you like to know?")
                .font(.callout.weight(.medium))

            Text("Type any question below or pick a suggestion to analyze this screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        .background(Color.primary.opacity(0.02))
    }

    private func suggestionButton(_ text: String) -> some View {
        Button(action: {
            inputPrompt = text
            sendQuery()
        }) {
            Text(text)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about screenshot…", text: $inputPrompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onSubmit { sendQuery() }

            Button(action: sendQuery) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Palette.accent : Color.secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(10)
    }

    private var canSend: Bool {
        !inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    private func sendQuery() {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnalyzing else { return }

        // Add user query message
        model.addMessage(to: screenshot, role: .user, content: trimmed)
        inputPrompt = ""
        errorText = nil
        isAnalyzing = true

        guard let data = screenshot.loadData(from: model.storeDirectory) else {
            errorText = "Could not load screenshot data."
            isAnalyzing = false
            return
        }

        Task {
            do {
                let markdownResponse = try await AnalyseService.analyse(
                    imageData: data,
                    query: trimmed
                )
                model.addMessage(to: screenshot, role: .assistant, content: markdownResponse)
            } catch {
                errorText = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

// MARK: - Chat Message Bubble

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
                        .foregroundStyle(Palette.onAccent)
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
            .shadow(color: Color.black.opacity(message.role == .assistant ? 0.05 : 0.0), radius: 3, y: 1)

            if message.role == .assistant {
                Spacer(minLength: 16)
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Palette.accent)
        } else {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var borderColor: Color {
        if message.role == .user {
            return Color.clear
        } else {
            return Color.primary.opacity(0.08)
        }
    }
}
