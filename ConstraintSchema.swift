// ConstraintSchema.swift
// Brazos — Form-Constrained Generation Engine
//
// The river doesn't decide where to go. The land does.
//
// A ConstraintSchema defines the structural boundary of valid output
// for any domain. The model fills the interior. If output doesn't
// fit the form, it doesn't exist.
//
// PARCRI invariants enforced:
//   1. Diffs only    — revalidation targets failed fields, not the whole
//   2. Intent first  — schema encodes what output means, not how to make it
//   3. Compress to learn — schema IS the compression of domain knowledge
//   4. Boundary on recursion — max depth is part of the schema
//   5. Reversible state — every generation attempt is a value, not a mutation

import Foundation

// MARK: - Core Protocol

/// A ConstraintSchema defines the shape of valid output for a domain.
/// It answers one question: given a generation result, is this structurally valid?
///
/// The schema does three things:
/// 1. Specifies the fields and types that output must contain
/// 2. Provides the structural prompt — the compressed form that tells
///    the model what shape to fill (not what content to generate)
/// 3. Validates output against the form and reports which fields failed
///
public protocol ConstraintSchema: Sendable {

    /// The output type this schema constrains.
    /// Must be Codable so generation results are always serializable
    /// and reversible (PARCRI #5).
    associatedtype Output: Codable & Sendable

    /// Human-readable name for this schema.
    /// e.g. "TEKS Lesson Plan", "Exempt Residential Drawing"
    var name: String { get }

    /// The structural prompt — the compressed representation of this
    /// schema's constraints, optimized for the model's context window.
    ///
    /// This is not a natural language prompt. It is the FORM itself,
    /// encoded as text. On a 4K context model, this must be tight.
    /// The entire thesis: if this is tight enough, 4K is abundant.
    ///
    /// - Parameter context: Domain-specific context from the DomainPack
    /// - Returns: The structural prompt string
    func structuralPrompt(context: SchemaContext) -> String

    /// Validate a generation result against this schema.
    ///
    /// Returns a ValidationResult containing:
    /// - Whether the output is structurally valid
    /// - Which specific fields/constraints failed (diffs only — PARCRI #1)
    /// - A correction hint for each failure (so retry is targeted, not blind)
    ///
    /// This is "Verification is Computation" at runtime.
    func validate(_ output: Output) -> ValidationResult

    /// Maximum retry depth for generation. Hard ceiling.
    /// PARCRI #4: boundary on recursion.
    var maxRetries: Int { get }
}

// MARK: - Default Implementation

extension ConstraintSchema {
    public var maxRetries: Int { 3 }
}

// MARK: - Schema Context

/// Context passed into structural prompt generation.
/// Contains domain-specific parameters that shape the prompt
/// without being the prompt itself.
public struct SchemaContext: Sendable {

    /// Key-value pairs of domain parameters.
    /// e.g. ["gradeLevel": "8", "subject": "Math", "standard": "8.1A"]
    public let parameters: [String: String]

    /// Optional prior output to refine (for diff-based retry).
    /// When present, the schema can generate a targeted correction
    /// prompt instead of a full generation prompt.
    public let priorAttempt: (any Sendable)?

    /// Optional explicit user intent beyond the domain parameters.
    /// e.g. "Focus on hands-on activities" or "Include ELL scaffolds"
    public let userIntent: String?

    public init(
        parameters: [String: String],
        priorAttempt: (any Sendable)? = nil,
        userIntent: String? = nil
    ) {
        self.parameters = parameters
        self.priorAttempt = priorAttempt
        self.userIntent = userIntent
    }
}

// MARK: - Validation Result

/// The result of validating output against a schema.
/// Reports exactly what failed and how to fix it — diffs only.
public struct ValidationResult: Sendable {

    /// Did the output pass all structural constraints?
    public let isValid: Bool

    /// Specific field-level failures. Empty if isValid == true.
    public let violations: [Violation]

    /// Overall confidence score 0.0–1.0.
    /// 1.0 = every constraint satisfied.
    /// Schema can define its own scoring logic.
    public let score: Double

    public init(isValid: Bool, violations: [Violation], score: Double) {
        self.isValid = isValid
        self.violations = violations
        self.score = score
    }

    /// Convenience: valid result with perfect score.
    public static let valid = ValidationResult(isValid: true, violations: [], score: 1.0)
}

// MARK: - Violation

/// A single structural violation — one field or constraint that failed.
public struct Violation: Sendable {

    /// Which field or constraint failed.
    /// e.g. "objective.bloom_level", "duration_minutes", "teks_alignment"
    public let field: String

    /// What went wrong.
    public let reason: String

    /// A targeted correction hint the generator can use on retry.
    /// This is the diff — not "regenerate everything" but "fix this specific thing."
    public let correctionHint: String

    /// Severity: .hard = output is invalid, .soft = output is suboptimal
    public let severity: Severity

    public enum Severity: Sendable {
        case hard   // structural failure — output cannot ship
        case soft   // quality issue — output works but could be better
    }

    public init(field: String, reason: String, correctionHint: String, severity: Severity = .hard) {
        self.field = field
        self.reason = reason
        self.correctionHint = correctionHint
        self.severity = severity
    }
}
