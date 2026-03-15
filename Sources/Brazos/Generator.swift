// Generator.swift
// Brazos — Form-Constrained Generation Engine
//
// The generator is the runtime loop of "Verification is Computation."
//
// 1. Schema produces structural prompt (compress to learn)
// 2. Backend generates within the prompt's constraints
// 3. Validator checks output against schema (verification)
// 4. If invalid: extract violations, build correction prompt (diffs only)
// 5. Retry with targeted fixes up to maxRetries (boundary on recursion)
// 6. Every attempt is captured in the ledger (reversible state)
//
// The generator never mutates. It produces a GenerationLedger —
// a complete, replayable record of every attempt.

import Foundation

// MARK: - Generator

/// The Brazos generation engine.
/// Stateless. Every call produces a self-contained ledger.
public struct Generator<Schema: ConstraintSchema>: Sendable {

    public let schema: Schema
    public let backend: any ModelBackend

    public init(schema: Schema, backend: any ModelBackend) {
        self.schema = schema
        self.backend = backend
    }

    /// Run form-constrained generation.
    ///
    /// Returns a complete ledger of all attempts, including the final
    /// valid output (or the best attempt if max retries exhausted).
    ///
    /// - Parameter context: Domain-specific context for this generation.
    /// - Returns: A GenerationLedger containing the full history.
    public func generate(context: SchemaContext) async throws -> GenerationLedger<Schema.Output> {

        var ledger = GenerationLedger<Schema.Output>(schemaName: schema.name)
        var currentContext = context

        for attempt in 0..<max(1, schema.maxRetries) {

            // Phase 1: Build prompt from schema
            let structuralPrompt = schema.structuralPrompt(context: currentContext)
            let userPrompt = buildUserPrompt(context: currentContext, attempt: attempt)

            let request = GenerationRequest(
                systemPrompt: structuralPrompt,
                userPrompt: userPrompt,
                maxTokens: 1024,
                temperature: attempt == 0 ? 0.3 : 0.2 // tighten on retry
            )

            // Phase 2: Generate
            let response: GenerationResponse
            do {
                response = try await backend.generate(request)
            } catch {
                ledger.record(
                    attempt: attempt,
                    raw: nil,
                    output: nil,
                    validation: nil,
                    error: .backendFailure(error.localizedDescription),
                    usage: nil
                )
                continue
            }

            // Phase 3: Parse output
            let output: Schema.Output
            do {
                output = try decode(response.text)
            } catch {
                ledger.record(
                    attempt: attempt,
                    raw: response.text,
                    output: nil,
                    validation: nil,
                    error: .decodingFailure(response.text),
                    usage: response.usage
                )
                // On decode failure, retry with explicit format correction
                currentContext = SchemaContext(
                    parameters: context.parameters,
                    priorAttempt: response.text,
                    userIntent: "Previous response was not valid JSON. Return ONLY valid JSON matching the schema."
                )
                continue
            }

            // Phase 4: Validate against schema
            let validation = schema.validate(output)

            ledger.record(
                attempt: attempt,
                raw: response.text,
                output: output,
                validation: validation,
                error: nil,
                usage: response.usage
            )

            // Phase 5: Check if valid
            if validation.isValid {
                ledger.finalize(output: output, status: .valid)
                return ledger
            }

            // Phase 6: Build correction context for retry (diffs only)
            let hardViolations = validation.violations.filter { $0.severity == .hard }
            if hardViolations.isEmpty {
                // Only soft violations — output is usable
                ledger.finalize(output: output, status: .softPass)
                return ledger
            }

            // Build targeted retry context — not "regenerate everything,"
            // just "fix these specific fields"
            currentContext = SchemaContext(
                parameters: context.parameters,
                priorAttempt: output,
                userIntent: buildCorrectionIntent(violations: hardViolations)
            )
        }

        // Exhausted retries — return best attempt
        ledger.finalize(
            output: ledger.bestAttempt,
            status: .exhausted
        )
        return ledger
    }

    // MARK: - Private Helpers

    private func buildUserPrompt(context: SchemaContext, attempt: Int) -> String {
        var parts: [String] = []

        // Domain parameters
        let params = context.parameters.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        if !params.isEmpty { parts.append(params) }

        // User intent
        if let intent = context.userIntent {
            parts.append(intent)
        }

        // Retry context
        if attempt > 0, context.priorAttempt != nil {
            parts.append("CORRECTION ATTEMPT \(attempt + 1). Fix ONLY the indicated violations.")
        }

        return parts.joined(separator: "\n\n")
    }

    private func buildCorrectionIntent(violations: [Violation]) -> String {
        let fixes = violations.map { v in
            "[\(v.field)] \(v.correctionHint)"
        }.joined(separator: "\n")

        return "Fix these structural violations:\n\(fixes)"
    }

    private func decode(_ text: String) throws -> Schema.Output {
        // Strip markdown code fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw BrazosError.decodingFailure(text)
        }
        return try JSONDecoder().decode(Schema.Output.self, from: data)
    }
}

// MARK: - Generation Ledger

/// Complete, immutable record of a generation run.
/// Every attempt is preserved. Replayable. Inspectable.
/// PARCRI #5: reversible state.
public struct GenerationLedger<Output: Codable & Sendable>: Sendable {

    public let schemaName: String
    public let startedAt: Date
    public private(set) var entries: [LedgerEntry<Output>]
    public private(set) var finalOutput: Output?
    public private(set) var status: GenerationStatus

    public init(schemaName: String) {
        self.schemaName = schemaName
        self.startedAt = Date()
        self.entries = []
        self.status = .pending
    }

    /// The best attempt so far — highest validation score.
    public var bestAttempt: Output? {
        entries
            .filter { $0.output != nil }
            .max(by: { ($0.validation?.score ?? 0) < ($1.validation?.score ?? 0) })
            .flatMap(\.output)
    }

    /// Total tokens consumed across all attempts.
    public var totalTokens: TokenUsage? {
        let usages = entries.compactMap(\.usage)
        guard !usages.isEmpty else { return nil }
        return TokenUsage(
            input: usages.reduce(0) { $0 + $1.input },
            output: usages.reduce(0) { $0 + $1.output }
        )
    }

    /// Number of attempts made.
    public var attemptCount: Int { entries.count }

    mutating func record(
        attempt: Int,
        raw: String?,
        output: Output?,
        validation: ValidationResult?,
        error: BrazosError?,
        usage: TokenUsage?
    ) {
        entries.append(LedgerEntry(
            attempt: attempt,
            timestamp: Date(),
            raw: raw,
            output: output,
            validation: validation,
            error: error,
            usage: usage
        ))
    }

    mutating func finalize(output: Output?, status: GenerationStatus) {
        self.finalOutput = output
        self.status = status
    }
}

// MARK: - Ledger Entry

/// A single generation attempt within a ledger.
public struct LedgerEntry<Output: Codable & Sendable>: Sendable {
    public let attempt: Int
    public let timestamp: Date
    public let raw: String?
    public let output: Output?
    public let validation: ValidationResult?
    public let error: BrazosError?
    public let usage: TokenUsage?
}

// MARK: - Generation Status

public enum GenerationStatus: Sendable {
    case pending     // not started
    case valid       // passed all constraints
    case softPass    // passed hard constraints, has soft violations
    case exhausted   // max retries hit, returning best attempt
    case failed      // no usable output produced
}

// MARK: - Errors

public enum BrazosError: Error, Sendable {
    case backendFailure(String)
    case decodingFailure(String)
    case schemaViolation([Violation])
    case retriesExhausted(Int)
}
