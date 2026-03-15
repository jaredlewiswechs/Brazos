// ModelBackend.swift
// Brazos — Form-Constrained Generation Engine
//
// The engine doesn't care where generation happens.
// On-device (Apple Foundation Models), remote (Claude API),
// or something that doesn't exist yet. The backend is a slot.
// The constraint schema is what matters.

import Foundation

// MARK: - Model Backend Protocol

/// Abstraction over any text generation model.
/// Brazos doesn't couple to a specific provider.
/// Apple Foundation Models, Claude, OpenAI, local GGUF — all are backends.
public protocol ModelBackend: Sendable {

    /// Human-readable identifier for this backend.
    /// e.g. "apple-foundation-4k", "claude-sonnet", "local-llama"
    var identifier: String { get }

    /// Maximum context window in tokens (approximate).
    /// The ConstraintSchema uses this to budget its structural prompt.
    var contextWindow: Int { get }

    /// Generate text from a prompt.
    ///
    /// - Parameter request: The generation request containing the prompt
    ///   and parameters.
    /// - Returns: The raw text output from the model.
    /// - Throws: If generation fails (network, timeout, model error).
    func generate(_ request: GenerationRequest) async throws -> GenerationResponse
}

// MARK: - Generation Request

/// A single generation request sent to a model backend.
public struct GenerationRequest: Sendable {

    /// The system-level instruction. For Brazos, this is always
    /// the structural prompt from the ConstraintSchema.
    public let systemPrompt: String

    /// The user-level prompt. Combines domain context with user intent.
    public let userPrompt: String

    /// Maximum tokens to generate.
    public let maxTokens: Int

    /// Temperature. Lower = more deterministic = more form-adherent.
    /// Brazos defaults low because we want the model to fill the mold,
    /// not improvise outside it.
    public let temperature: Double

    public init(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int = 1024,
        temperature: Double = 0.3
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

// MARK: - Generation Response

/// Raw response from a model backend.
public struct GenerationResponse: Sendable {

    /// The generated text.
    public let text: String

    /// Token usage (if reported by backend).
    public let usage: TokenUsage?

    /// Time elapsed for generation.
    public let elapsed: TimeInterval

    public init(text: String, usage: TokenUsage? = nil, elapsed: TimeInterval = 0) {
        self.text = text
        self.usage = usage
        self.elapsed = elapsed
    }
}

// MARK: - Token Usage

/// Token accounting. Track this — it proves the compression thesis.
public struct TokenUsage: Sendable {

    /// Tokens consumed by system + user prompt.
    public let input: Int

    /// Tokens generated in response.
    public let output: Int

    /// Total.
    public var total: Int { input + output }

    /// Compression ratio: how much of the context window did we actually use?
    /// Lower is better. If this is consistently < 0.4 on a 4K window,
    /// the thesis holds.
    public func compressionRatio(windowSize: Int) -> Double {
        Double(input) / Double(windowSize)
    }

    public init(input: Int, output: Int) {
        self.input = input
        self.output = output
    }
}
