import Foundation

/// Service for making multimodal requests and dynamic model discovery with the Google Gemini REST API.
enum GeminiService {
    private static let apiKeyDefaultsKey = "gemini.apiKey"
    private static let modelDefaultsKey = "gemini.model"

    /// The stored API key, saved locally in UserDefaults.
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiKeyDefaultsKey) }
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

    static var defaultModels: [String] {
        [
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "gemini-1.5-pro"
        ]
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

    /// Discovers active multimodal models from the Gemini API.
    static func getMultimodalModels(useHeaderAuth: Bool = false) async throws -> [ModelInfo] {
        guard hasAPIKey else {
            throw GeminiError.missingAPIKey
        }

        let key = apiKey
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
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw GeminiError.apiError(message: errorMsg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]] else {
            return []
        }

        let excluded = ["embedding", "embed", "aqa", "imagen", "veo", "learnlm", "chirp", "music"]

        var filtered: [ModelInfo] = []
        for m in modelsArray {
            let name = (m["name"] as? String) ?? ""
            let methods = (m["supportedGenerationMethods"] as? [String]) ?? []

            // 1. Must support generateContent
            guard methods.contains("generateContent") else { continue }

            // 2. Must be a Gemini multimodal model
            let nameLower = name.lowercased()
            guard nameLower.contains("gemini") else { continue }

            // 3. Exclude embedding or non-text/image models
            if excluded.contains(where: { nameLower.contains($0) }) { continue }

            filtered.append(
                ModelInfo(
                    name: name,
                    displayName: (m["displayName"] as? String) ?? name,
                    description: (m["description"] as? String) ?? "",
                    inputTokenLimit: m["inputTokenLimit"] as? Int,
                    outputTokenLimit: m["outputTokenLimit"] as? Int
                )
            )
        }

        filtered.sort { $0.name > $1.name }
        return filtered
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
            let errorMsg = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw GeminiError.apiError(message: errorMsg)
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

    private static func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            return message
        }
        return nil
    }
}

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case apiError(message: String)

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
        case .apiError(let message):
            return "Gemini API error: \(message)"
        }
    }
}
