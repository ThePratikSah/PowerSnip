import Foundation

/// Generates a concise 4–5 word title for a screenshot using the Gemini API.
enum TitleGenerator {
    static func generateTitle(for screenshot: Screenshot, model: AppModel) async {
        guard let imageData = screenshot.loadData(from: model.storeDirectory) else { return }
        let prompt = "Generate a strict 4 to 5 word concise title describing this image snippet. No quotes, periods, or prefixes. Reply with ONLY the title words, nothing else."
        do {
            let raw = try await GeminiService.generateAnalysis(imageData: imageData, query: prompt)
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? raw
            await MainActor.run {
                model.updateTitle(for: screenshot, title: String(clean.prefix(60)))
            }
        } catch {
            // Title generation failure is non-fatal; keep the default timestamp title
            await MainActor.run {
                screenshot.isGeneratingTitle = false
            }
        }
    }
}
