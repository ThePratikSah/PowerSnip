import Foundation

/// Service for making multimodal requests and discovering official active Google Gemini models.
enum GeminiService {
    private static let apiKeyDefaultsKey = "gemini.apiKey"
    private static let modelDefaultsKey = "gemini.model"

    /// The stored API key, saved locally in UserDefaults.
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? "" }
        set {
            UserDefaults.standard.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: apiKeyDefaultsKey
            )
        }
    }

    /// True if an API key is currently saved.
    static var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    /// The Gemini model to use. Defaults to gemini-2.5-flash.
    static var model: String {
        get { UserDefaults.standard.string(forKey: modelDefaultsKey) ?? "gemini-2.5-flash" }
        set { UserDefaults.standard.set(newValue, forKey: modelDefaultsKey) }
    }

    /// Curated list of current, official, non-deprecated Google Gemini multimodal models.
    static var officialModels: [ModelInfo] {
        [
            ModelInfo(
                name: "models/gemini-2.5-flash",
                displayName: "Gemini 2.5 Flash (Recommended)",
                description: "Latest fast multimodal model with superior speed and multimodal reasoning.",
                inputTokenLimit: 1_048_576,
                outputTokenLimit: 8_192
            ),
            ModelInfo(
                name: "models/gemini-2.0-flash",
                displayName: "Gemini 2.0 Flash",
                description: "Second-generation multimodal model with ultra-low latency.",
                inputTokenLimit: 1_048_576,
                outputTokenLimit: 8_192
            ),
            ModelInfo(
                name: "models/gemini-1.5-pro",
                displayName: "Gemini 1.5 Pro",
                description: "Advanced reasoning model for complex visual inspection and deep analysis.",
                inputTokenLimit: 2_097_152,
                outputTokenLimit: 8_192
            ),
            ModelInfo(
                name: "models/gemini-1.5-flash",
                displayName: "Gemini 1.5 Flash",
                description: "Lightweight and efficient production multimodal model.",
                inputTokenLimit: 1_048_576,
                outputTokenLimit: 8_192
            )
        ]
    }

    static var defaultModels: [String] {
        officialModels.map(\.shortName)
    }

    static var availableModels: [String] {
        defaultModels
    }

    /// Clean model info structure returned by model discovery.
    struct ModelInfo: Identifiable, Hashable, Sendable {
        var id: String { name }
        let name: String
        let displayName: String
        let description: String
        let inputTokenLimit: Int?
        let outputTokenLimit: Int?

        var shortName: String {
            name.replacingOccurrences(of: "models/", with: "")
        }
    }

    /// Discovers active, official, non-deprecated multimodal models from the Gemini API.
    static func getMultimodalModels(
        customApiKey: String? = nil,
        useHeaderAuth: Bool = false
    ) async throws -> [ModelInfo] {
        let key = customApiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? apiKey
        guard !key.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        var request: URLRequest
        if useHeaderAuth {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
                throw GeminiError.invalidURL
            }
            request = URLRequest(url: url)
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        } else {
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(encodedKey)") else {
                throw GeminiError.invalidURL
            }
            request = URLRequest(url: url)
        }

        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]] else {
            return officialModels
        }

        // Keywords indicating deprecated, embedding, or non-multimodal models
        let excludedKeywords = [
            "deprecated",
            "discontinued",
            "legacy",
            "1.0",
            "pro-vision",
            "embedding",
            "embed",
            "aqa",
            "imagen",
            "veo",
            "learnlm",
            "chirp",
            "music",
            "bison",
            "gecko",
            "tuned",
            "experimental",
            "preview-0"
        ]

        var discovered: [ModelInfo] = []
        for m in modelsArray {
            let name = (m["name"] as? String) ?? ""
            let displayName = (m["displayName"] as? String) ?? name
            let description = (m["description"] as? String) ?? ""
            let methods = (m["supportedGenerationMethods"] as? [String]) ?? []

            // 1. Must support generateContent
            guard methods.contains("generateContent") else { continue }

            // 2. Must be a Gemini family model
            let nameLower = name.lowercased()
            guard nameLower.contains("gemini") else { continue }

            // 3. Exclude deprecated, obsolete, embedding, or specialized models
            let combinedText = "\(nameLower) \(displayName.lowercased()) \(description.lowercased())"
            let isExcluded = excludedKeywords.contains { combinedText.contains($0) }
            guard !isExcluded else { continue }

            discovered.append(
                ModelInfo(
                    name: name,
                    displayName: displayName,
                    description: description,
                    inputTokenLimit: m["inputTokenLimit"] as? Int,
                    outputTokenLimit: m["outputTokenLimit"] as? Int
                )
            )
        }

        guard !discovered.isEmpty else {
            return officialModels
        }

        // Sort so the latest official flash/pro versions are prioritized
        discovered.sort { a, b in
            let scoreA = modelPriorityScore(a.name)
            let scoreB = modelPriorityScore(b.name)
            if scoreA != scoreB {
                return scoreA > scoreB
            }
            return a.name > b.name
        }

        return discovered
    }

    private static func modelPriorityScore(_ name: String) -> Int {
        if name.contains("gemini-2.5-flash") { return 100 }
        if name.contains("gemini-2.5-pro") { return 90 }
        if name.contains("gemini-2.0-flash") { return 80 }
        if name.contains("gemini-1.5-pro") { return 70 }
        if name.contains("gemini-1.5-flash") { return 60 }
        return 10
    }

    /// Calls the official Google Gemini generateContent API with image and query.
    static func generateAnalysis(
        imageData: Data,
        query: String,
        useHeaderAuth: Bool = false
    ) async throws -> String {
        guard hasAPIKey else {
            throw GeminiError.missingAPIKey
        }

        let key = apiKey
        let selectedModel = model
        let normalizedModel = selectedModel.starts(with: "models/") ? selectedModel : "models/\(selectedModel)"

        var request: URLRequest
        if useHeaderAuth {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(normalizedModel):generateContent") else {
                throw GeminiError.invalidURL
            }
            request = URLRequest(url: url)
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        } else {
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(normalizedModel):generateContent?key=\(encodedKey)") else {
                throw GeminiError.invalidURL
            }
            request = URLRequest(url: url)
        }

        let base64Image = imageData.base64EncodedString()

        let promptText = """
        You are an expert AI assistant analyzing a macOS screen capture snippet.
        The user asked: "\(query)"

        Please provide a concise, clear, and well-structured answer using markdown formatting:
        - Use ## or ### headers to separate ideas
        - Use bullet points (- ) or numbered lists (1. ) for clarity
        - Use code blocks (```) for any code, commands, or data
        - Highlight key items in **bold**
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": promptText
                        ],
                        [
                            "inlineData": [
                                "mimeType": "image/png",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorDetails = parseErrorDetails(from: data)
            let message = errorDetails.message ?? "HTTP \(httpResponse.statusCode)"
            let status = errorDetails.status ?? ""

            if httpResponse.statusCode == 429
                || status == "RESOURCE_EXHAUSTED"
                || message.localizedCaseInsensitiveContains("quota")
                || message.localizedCaseInsensitiveContains("rate limit")
                || message.localizedCaseInsensitiveContains("resource has been exhausted") {
                throw GeminiError.rateLimitExceeded(statusCode: httpResponse.statusCode, message: message)
            } else if httpResponse.statusCode == 400 && message.localizedCaseInsensitiveContains("api key") {
                throw GeminiError.invalidAPIKey(message: message)
            } else {
                throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.emptyResponse
        }

        return text
    }

    private static func parseErrorDetails(from data: Data) -> (code: Int?, message: String?, status: String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorObj = json["error"] as? [String: Any] else {
            return (nil, nil, nil)
        }
        let code = errorObj["code"] as? Int
        let message = errorObj["message"] as? String
        let status = errorObj["status"] as? String
        return (code, message, status)
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        parseErrorDetails(from: data).message
    }
}

enum GeminiError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case rateLimitExceeded(statusCode: Int, message: String)
    case invalidAPIKey(message: String)
    case apiError(statusCode: Int, message: String)

    var isRateLimit: Bool {
        if case .rateLimitExceeded = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Please provide a Gemini API key to analyze screenshots."
        case .invalidURL:
            return "Invalid Gemini API endpoint URL."
        case .invalidResponse:
            return "Unexpected response from Gemini servers."
        case .emptyResponse:
            return "Gemini returned an empty response. Try asking in a different way."
        case .rateLimitExceeded(let code, let message):
            return "Rate Limit Exceeded (\(code)): \(message)"
        case .invalidAPIKey(let message):
            return "Invalid API Key: \(message)"
        case .apiError(let code, let message):
            return "Gemini API Error (\(code)): \(message)"
        }
    }
}
