// AppleFoundationBackend.swift
// Brazos — Apple Foundation Models Backend
//
// The backend that proves the thesis. 4K context window.
// On-device. Private. Zero API cost. Fast.
//
// If the constraint schema is tight enough, 4K is abundant.
//
// NOTE: Requires iOS 26+ / macOS 26+ with Apple Intelligence enabled.
// This file compiles only when FoundationModels framework is available.
// For earlier targets or CI, use MockBackend.

import Foundation
import Brazos

// Gate on availability — FoundationModels ships with iOS 26 / macOS 26
#if canImport(FoundationModels)
import FoundationModels

// MARK: - Apple Foundation Models Backend

/// On-device generation via Apple's Foundation Models framework.
/// 4096-token context window. No network. No API key. No cost.
///
/// The entire Brazos thesis rests on this: if form-constrained prompts
/// are tight enough, this small fast model produces structurally valid
/// output that passes schema validation.
public struct AppleFoundationBackend: ModelBackend {

    public let identifier = "apple-foundation-4k"
    public let contextWindow = 4096

    public init() {}

    public func generate(_ request: GenerationRequest) async throws -> GenerationResponse {
        let session = LanguageModelSession()

        let start = CFAbsoluteTimeGetCurrent()

        // Combine system + user into a single prompt.
        // Apple FM doesn't have a separate system prompt slot —
        // everything goes into one context. This is fine because
        // the structural prompt IS the system instruction,
        // compressed to fit.
        let fullPrompt = """
        \(request.systemPrompt)

        \(request.userPrompt)
        """

        let response = try await session.respond(to: fullPrompt)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // Apple FM doesn't expose token counts directly,
        // so we estimate from character counts.
        // ~4 chars per token is a reasonable approximation.
        let estimatedInput = fullPrompt.count / 4
        let estimatedOutput = response.content.count / 4

        return GenerationResponse(
            text: response.content,
            usage: TokenUsage(input: estimatedInput, output: estimatedOutput),
            elapsed: elapsed
        )
    }
}

#else

// MARK: - Stub for platforms without FoundationModels

/// Placeholder that throws a clear error on platforms where
/// Apple Foundation Models aren't available.
public struct AppleFoundationBackend: ModelBackend {

    public let identifier = "apple-foundation-unavailable"
    public let contextWindow = 4096

    public init() {}

    public func generate(_ request: GenerationRequest) async throws -> GenerationResponse {
        throw BrazosError.backendFailure(
            "Apple Foundation Models requires iOS 26+ / macOS 26+ with Apple Intelligence enabled. " +
            "Use MockBackend for testing or ClaudeBackend for remote generation."
        )
    }
}

#endif
