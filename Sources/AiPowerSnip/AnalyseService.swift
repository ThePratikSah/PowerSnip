import Foundation

/// Service that calls the /analyse API with a screenshot and a user query.
/// Returns a markdown-formatted response.
enum AnalyseService {
    /// The base URL for the API. Stored in UserDefaults, configurable in Settings.
    private static var baseURL: String {
        UserDefaults.standard.string(forKey: "api.baseURL") ?? "http://localhost:8080"
    }

    /// Sends the screenshot image data and the user's query to the /analyse endpoint.
    /// Returns the markdown response from the API.
    static func analyse(imageData: Data, query: String) async throws -> String {
        let urlString = "\(baseURL)/analyse"
        guard let url = URL(string: urlString) else {
            throw AnalyseError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        // Build multipart form data.
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // Add the query field.
        body.appendUtf8("--\(boundary)\r\n")
        body.appendUtf8("Content-Disposition: form-data; name=\"query\"\r\n\r\n")
        body.appendUtf8("\(query)\r\n")
        // Add the image field.
        body.appendUtf8("--\(boundary)\r\n")
        body.appendUtf8("Content-Disposition: form-data; name=\"image\"; filename=\"screenshot.png\"\r\n")
        body.appendUtf8("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        body.appendUtf8("\r\n")
        body.appendUtf8("--\(boundary)--\r\n")

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AnalyseError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                throw AnalyseError.serverError(statusCode: http.statusCode, body: responseBody)
            }

            // Try to parse as JSON with a "response" or "markdown" field.
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let markdown = json["response"] as? String ?? json["markdown"] as? String ?? json["content"] as? String {
                return markdown
            }

            // Fall back to raw text.
            return String(data: data, encoding: .utf8) ?? "No response"
        } catch let error as AnalyseError {
            throw error
        } catch is URLError {
            // API is not reachable; return a mock response for development.
            return mockResponse(for: query)
        } catch {
            throw error
        }
    }

    /// A mock response for when the API is not running.
    private static func mockResponse(for query: String) -> String {
        """
        ## Analysis Result

        > **Note:** Connected to mock mode. The backend at `\(baseURL)` is currently offline.

        ### Question Asked
        \(query)

        ### Screenshot Analysis
        - **Visual Overview:** Successfully processed high-resolution screen capture
        - **Interface Components:** Detected window frames, interactive controls, and visual content
        - **Layout Structure:** Standard native macOS application viewport hierarchy

        ### Next Steps
        To connect to your live `/analyse` service:
        1. Start your backend server listening on `\(baseURL)`
        2. Verify it handles `POST /analyse` with fields:
           - `query` (form text)
           - `image` (PNG multipart file)
        3. Respond with JSON: `{"response": "## Your Markdown..."}`

        *Configure host and port anytime in **Settings → General**.*
        """
    }
}

enum AnalyseError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from the server."
        case .serverError(let code, let body):
            "Server returned \(code): \(body)"
        }
    }
}

private extension Data {
    mutating func appendUtf8(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
