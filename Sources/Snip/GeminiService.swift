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
        description: "Fast multimodal model balancing speed and deep visual reasoning.",
        inputTokenLimit: 1_048_576,
        outputTokenLimit: 65_536
      ),
      ModelInfo(
        name: "models/gemini-2.5-pro",
        displayName: "Gemini 2.5 Pro",
        description: "Most capable reasoning model for complex code and dense visual inspection.",
        inputTokenLimit: 1_048_576,
        outputTokenLimit: 65_536
      ),
      ModelInfo(
        name: "models/gemini-2.5-flash-lite",
        displayName: "Gemini 2.5 Flash-Lite",
        description: "Ultra-fast, high-throughput model with generous rate limits.",
        inputTokenLimit: 1_048_576,
        outputTokenLimit: 65_536
      ),
      ModelInfo(
        name: "models/gemini-2.0-flash",
        displayName: "Gemini 2.0 Flash",
        description: "Second-generation multimodal model with low latency.",
        inputTokenLimit: 1_048_576,
        outputTokenLimit: 8_192
      ),
    ]
  }

  static var defaultModels: [String] {
    officialModels.map(\.shortName)
  }

  static var availableModels: [String] {
    defaultModels
  }

  /// Clean model info structure returned by model discovery.
  struct ModelInfo: Identifiable, Hashable, Sendable, Codable {
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

  private struct ModelsListResponse: Decodable {
    struct RawModel: Decodable {
      let name: String
      let displayName: String?
      let description: String?
      let inputTokenLimit: Int?
      let outputTokenLimit: Int?
      let supportedGenerationMethods: [String]?
    }
    let models: [RawModel]?
  }

  /// Discovers active, official, non-deprecated multimodal models from the Gemini API.
  static func getMultimodalModels(
    customApiKey: String? = nil,
    useHeaderAuth: Bool = true
  ) async throws -> [ModelInfo] {
    let key = customApiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? apiKey
    guard !key.isEmpty else {
      throw GeminiError.missingAPIKey
    }

    let request = try buildRequest(
      endpoint: "https://generativelanguage.googleapis.com/v1beta/models",
      apiKey: key,
      method: "GET",
      timeout: 20,
      useHeaderAuth: useHeaderAuth
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GeminiError.invalidResponse
    }

    if !(200...299).contains(httpResponse.statusCode) {
      throw mapError(statusCode: httpResponse.statusCode, data: data)
    }

    guard let decoded = try? JSONDecoder().decode(ModelsListResponse.self, from: data),
      let rawModels = decoded.models
    else {
      return officialModels
    }

    // Filter against model ID / display name to avoid false positives in long descriptions
    let excludedNameTokens = [
      "1.0", "1.5", "pro-vision", "embedding", "embed", "aqa",
      "imagen", "veo", "learnlm", "chirp", "bison", "gecko",
      "tuned", "experimental", "exp-", "preview-0", "tts", "image-generation",
    ]

    var discovered: [ModelInfo] = []
    for m in rawModels {
      let methods = m.supportedGenerationMethods ?? []
      guard methods.contains("generateContent") else { continue }

      let nameLower = m.name.lowercased()
      guard nameLower.contains("gemini") else { continue }

      let descLower = (m.description ?? "").lowercased()
      let isDeprecated = descLower.contains("deprecated") || descLower.contains("discontinued")
      let hasExcludedToken = excludedNameTokens.contains { nameLower.contains($0) }

      guard !isDeprecated && !hasExcludedToken else { continue }

      discovered.append(
        ModelInfo(
          name: m.name,
          displayName: m.displayName ?? m.name,
          description: m.description ?? "",
          inputTokenLimit: m.inputTokenLimit,
          outputTokenLimit: m.outputTokenLimit
        )
      )
    }

    guard !discovered.isEmpty else {
      return officialModels
    }

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
    if name.contains("gemini-2.5-flash") && !name.contains("lite") { return 100 }
    if name.contains("gemini-2.5-pro") { return 95 }
    if name.contains("gemini-2.5-flash-lite") { return 90 }
    if name.contains("gemini-2.0-flash") { return 80 }
    return 50
  }

  /// Calls the official Google Gemini generateContent API with image and query.
  static func generateAnalysis(
    imageData: Data,
    query: String,
    useHeaderAuth: Bool = true
  ) async throws -> String {
    guard hasAPIKey else {
      throw GeminiError.missingAPIKey
    }

    let key = apiKey
    let selectedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedModel =
      selectedModel.starts(with: "models/") ? selectedModel : "models/\(selectedModel)"

    var request = try buildRequest(
      endpoint:
        "https://generativelanguage.googleapis.com/v1beta/\(normalizedModel):generateContent",
      apiKey: key,
      method: "POST",
      timeout: 60,
      useHeaderAuth: useHeaderAuth
    )

    let base64Image = imageData.base64EncodedString()
    let mimeType = detectMimeType(for: imageData)

    let userQueryPart =
      query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? "Identify what is in this captured region and provide relevant information or actions."
      : query

    let promptText = """
      You are the visual search intelligence for a macOS desktop capture tool (functioning like Android's 'Circle to Search').
      Analyze the attached screen snippet and address the user's intent.

      User query or context: "\(userQueryPart)"

      Analyze the image and respond using the following structured logic:

      1. Identification & Core Answer:
         - State clearly and concisely what is shown (product, error code, person/celebrity, landmark, UI component, math problem, or foreign text).
         - Give the immediate direct answer, translation, solution, or explanation in 2-4 sentences.

      2. Product & Shopping Match (ONLY if a physical product, gadget, apparel, book, or hardware is detected):
         - **Identified Item**: Specific brand, model name, colorway, or edition.
         - **Estimated Price / Category**: If identifiable.
         - **Where to Find / Buy**: Provide clear web search and marketplace search links formatted as Markdown links:
           - Search on Google: `[Search on Google](https://www.google.com/search?q=<URL_ENCODED_PRODUCT_QUERY>)`
           - Search on Amazon: `[Search on Amazon](https://www.amazon.com/s?k=<URL_ENCODED_PRODUCT_QUERY>)`
           - Official product/manufacturer page name (if known).

      3. Technical / Code Context (ONLY if code, terminal logs, or error dialogues are detected):
         - Explain the root cause in 1-2 bullet points.
         - Provide the exact corrected code block or terminal command to resolve it.

      4. Quick Search Suggestions:
         - Provide 2-3 specific queries the user can click or copy to search deeper (e.g., `> "exact model name specs"`, `> "how to fix error X"`).

      Formatting Rules:
      - Keep the response concise, visual, and glanceable.
      - Use bullet points (`- `) and bold text (`**`) for key attributes.
      - Ensure all search URLs use valid percent-encoded query strings (e.g., replace spaces with `+` or `%20`).
      - Do not add conversational fluff or introductory greetings. Start directly with the identification.
      """

    let requestBody: [String: Any] = [
      "contents": [
        [
          "parts": [
            ["text": promptText],
            [
              "inlineData": [
                "mimeType": mimeType,
                "data": base64Image,
              ]
            ],
          ]
        ]
      ]
    ]

    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GeminiError.invalidResponse
    }

    if !(200...299).contains(httpResponse.statusCode) {
      throw mapError(statusCode: httpResponse.statusCode, data: data)
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let candidates = json["candidates"] as? [[String: Any]],
      let firstCandidate = candidates.first
    else {
      throw GeminiError.emptyResponse
    }

    // Check if blocked by safety or recitation filters before content was produced
    if let finishReason = firstCandidate["finishReason"] as? String,
      finishReason == "SAFETY" || finishReason == "BLOCKLIST"
        || finishReason == "PROHIBITED_CONTENT"
    {
      throw GeminiError.apiError(
        statusCode: 200,
        message: "Response was blocked due to content safety filters (\(finishReason))."
      )
    }

    guard let content = firstCandidate["content"] as? [String: Any],
      let parts = content["parts"] as? [[String: Any]]
    else {
      throw GeminiError.emptyResponse
    }

    // Concatenate all non-thought text parts (handles Gemini 2.5 thinking blocks cleanly)
    let text =
      parts
      .filter { ($0["thought"] as? Bool) != true }
      .compactMap { $0["text"] as? String }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !text.isEmpty else {
      throw GeminiError.emptyResponse
    }

    return text
  }

  // MARK: - Helpers

  private static func buildRequest(
    endpoint: String,
    apiKey: String,
    method: String,
    timeout: TimeInterval,
    useHeaderAuth: Bool
  ) throws -> URLRequest {
    var request: URLRequest
    if useHeaderAuth {
      guard let url = URL(string: endpoint) else {
        throw GeminiError.invalidURL
      }
      request = URLRequest(url: url)
      request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    } else {
      var components = URLComponents(string: endpoint)
      components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
      guard let url = components?.url else {
        throw GeminiError.invalidURL
      }
      request = URLRequest(url: url)
    }
    request.httpMethod = method
    request.timeoutInterval = timeout
    return request
  }

  private static func mapError(statusCode: Int, data: Data) -> GeminiError {
    let errorDetails = parseErrorDetails(from: data)
    let message = errorDetails.message ?? "HTTP \(statusCode)"
    let status = errorDetails.status ?? ""

    if statusCode == 429
      || status == "RESOURCE_EXHAUSTED"
      || message.localizedCaseInsensitiveContains("quota")
      || message.localizedCaseInsensitiveContains("rate limit")
      || message.localizedCaseInsensitiveContains("resource has been exhausted")
    {
      return .rateLimitExceeded(statusCode: statusCode, message: message)
    } else if (statusCode == 400 || statusCode == 403)
      && (message.localizedCaseInsensitiveContains("api key")
        || status == "INVALID_ARGUMENT" && message.localizedCaseInsensitiveContains("key"))
    {
      return .invalidAPIKey(message: message)
    } else {
      return .apiError(statusCode: statusCode, message: message)
    }
  }

  private static func detectMimeType(for data: Data) -> String {
    guard let firstByte = data.first else { return "image/png" }
    switch firstByte {
    case 0xFF: return "image/jpeg"
    case 0x89: return "image/png"
    case 0x47: return "image/gif"
    case 0x52 where data.count >= 12: return "image/webp"
    default: return "image/png"
    }
  }

  private static func parseErrorDetails(from data: Data) -> (
    code: Int?, message: String?, status: String?
  ) {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let errorObj = json["error"] as? [String: Any]
    else {
      return (nil, nil, nil)
    }
    return (
      errorObj["code"] as? Int,
      errorObj["message"] as? String,
      errorObj["status"] as? String
    )
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
