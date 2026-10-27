import Foundation

/// Service for making multimodal requests directly to the Google Gemini API.
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

    static let availableModels = [
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-1.5-flash",
        "gemini-1.5-pro"
    ]

    /// Calls the official Google Gemini generateContent API with image and query.
    static func generateAnalysis(imageData: Data, query: String) async throws -> String {
        guard hasAPIKey else {
            throw GeminiError.missingAPIKey
        }

        let key = apiKey
        let selectedModel = model
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(selectedModel):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let base64Image = imageData.base64EncodedString()

        // System instructions to guide Gemini for screenshot analysis
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
                            "inlineData": [
                                "mimeType": "image/png",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": promptText
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        // Check for HTTP errors or Gemini API error objects
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw GeminiError.apiError(message: message)
            }
            let rawBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw GeminiError.apiError(message: rawBody)
        }

        // Parse candidate response
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
