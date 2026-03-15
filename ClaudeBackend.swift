// ClaudeBackend.swift
// Brazos — Claude API Backend
//
// Remote backend for when you need more than 4K.
// Same interface as AppleFoundationBackend.
// The Generator doesn't care which one it's talking to.

import Foundation
import Brazos

// MARK: - Claude Backend

/// Remote generation via Anthropic Claude API.
/// Use when Apple Foundation Models isn't available,
/// or when you need the full context window for complex schemas.
public struct ClaudeBackend: ModelBackend {

    public let identifier: String
    public let contextWindow: Int

    private let apiKey: String
    private let model: String
    private let baseURL: URL

    /// Initialize with API key and model.
    ///
    /// - Parameters:
    ///   - apiKey: Anthropic API key
    ///   - model: Model identifier (default: claude-sonnet-4-20250514)
    public init(
        apiKey: String,
        model: String = "claude-sonnet-4-20250514"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.identifier = "claude-\(model)"
        self.contextWindow = 200_000
        self.baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    }

    public func generate(_ request: GenerationRequest) async throws -> GenerationResponse {
        let start = CFAbsoluteTimeGetCurrent()

        // Build request body
        let body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "system": request.systemPrompt,
            "messages": [
                ["role": "user", "content": request.userPrompt]
            ]
        ]

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BrazosError.backendFailure("Claude API error: \(errorText)")
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String ?? ""

        // Extract token usage
        let usage: TokenUsage?
        if let usageDict = json?["usage"] as? [String: Any],
           let inputTokens = usageDict["input_tokens"] as? Int,
           let outputTokens = usageDict["output_tokens"] as? Int {
            usage = TokenUsage(input: inputTokens, output: outputTokens)
        } else {
            usage = nil
        }

        return GenerationResponse(text: text, usage: usage, elapsed: elapsed)
    }
}
