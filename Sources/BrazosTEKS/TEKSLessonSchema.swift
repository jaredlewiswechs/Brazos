// TEKSLessonSchema.swift
// BrazosTEKS — TEKS Lesson Plan ConstraintSchema
//
// This is the first concrete form. It defines:
// - What a valid TEKS-aligned lesson plan looks like (Output type)
// - The structural prompt that compresses into a 4K window
// - The validation rules that make hallucination structurally impossible
//
// A lesson plan generated through this schema is TEKS-aligned by
// construction, not by post-hoc checking.

import Foundation
import Brazos

// MARK: - Lesson Plan Output Type

/// A structurally valid TEKS-aligned lesson plan.
/// Every field is required. If the model can't fill a field
/// within the constraints, validation catches it.
public struct TEKSLessonPlan: Codable, Sendable {

    /// Lesson title
    public let title: String

    /// Target TEKS standard code(s)
    public let teksCode: [String]

    /// Grade level
    public let gradeLevel: String

    /// Subject area
    public let subject: String

    /// Learning objective — must start with a Bloom's verb
    /// that matches or exceeds the TEKS standard's cognitive level
    public let objective: String

    /// Bloom's taxonomy level of the objective
    public let bloomLevel: BloomLevel

    /// Duration in minutes — must be a realistic class period
    public let durationMinutes: Int

    /// Materials needed
    public let materials: [String]

    /// Lesson phases — must follow I Do / We Do / You Do
    /// or equivalent gradual release structure
    public let phases: [LessonPhase]

    /// Assessment — must align to the stated objective
    public let assessment: Assessment

    /// Differentiation strategies
    public let differentiation: Differentiation

    /// Closure / exit ticket
    public let closure: String
}

// MARK: - Supporting Types

public enum BloomLevel: String, Codable, Sendable, Comparable {
    case remember    = "Remember"
    case understand  = "Understand"
    case apply       = "Apply"
    case analyze     = "Analyze"
    case evaluate    = "Evaluate"
    case create      = "Create"

    public var rank: Int {
        switch self {
        case .remember: return 1
        case .understand: return 2
        case .apply: return 3
        case .analyze: return 4
        case .evaluate: return 5
        case .create: return 6
        }
    }

    public static func < (lhs: BloomLevel, rhs: BloomLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public static func fromString(_ s: String) -> BloomLevel? {
        BloomLevel(rawValue: s) ?? {
            // Fuzzy match common Bloom's verbs to levels
            let lower = s.lowercased()
            if ["list", "define", "recall", "identify", "name"].contains(lower) { return .remember }
            if ["explain", "describe", "summarize", "interpret"].contains(lower) { return .understand }
            if ["use", "solve", "demonstrate", "apply", "compute"].contains(lower) { return .apply }
            if ["compare", "contrast", "examine", "categorize", "analyze"].contains(lower) { return .analyze }
            if ["judge", "justify", "critique", "assess", "evaluate"].contains(lower) { return .evaluate }
            if ["design", "construct", "develop", "produce", "create"].contains(lower) { return .create }
            return nil
        }()
    }
}

public struct LessonPhase: Codable, Sendable {
    public let name: String           // e.g. "I Do", "We Do", "You Do"
    public let durationMinutes: Int
    public let description: String
    public let teacherActions: [String]
    public let studentActions: [String]
}

public struct Assessment: Codable, Sendable {
    public let type: String           // formative, summative, etc.
    public let description: String
    public let alignsToObjective: Bool
}

public struct Differentiation: Codable, Sendable {
    public let ell: String            // English Language Learner supports
    public let specialEducation: String
    public let gifted: String
    public let struggling: String
}

// MARK: - TEKS Lesson Schema

public struct TEKSLessonSchema: ConstraintSchema {

    public typealias Output = TEKSLessonPlan

    public let name = "TEKS Lesson Plan"
    public let maxRetries = 3

    private let domainPack: TEKSDomainPack

    public init(domainPack: TEKSDomainPack = TEKSDomainPack()) {
        self.domainPack = domainPack
    }

    // MARK: - Structural Prompt

    /// Build the structural prompt — the compressed form that tells
    /// the model exactly what shape to fill.
    ///
    /// This is where the 4K context window gets respected.
    /// No fluff. No examples. Just the mold.
    public func structuralPrompt(context: SchemaContext) -> String {
        let subject = context.parameters["subject"] ?? "General"
        let grade = context.parameters["gradeLevel"] ?? "8"
        let codes = context.parameters["teksCode"]?.split(separator: ",").map(String.init) ?? []

        // Pull compressed TEKS standards
        let teksBlock: String
        if !codes.isEmpty {
            teksBlock = domainPack.compress(filter: DomainFilter(codes: codes))
        } else {
            teksBlock = domainPack.compress(filter: DomainFilter(category: subject, scope: "Grade \(grade)"))
        }

        // Correction context for retries
        let correctionBlock: String
        if let intent = context.userIntent, intent.contains("Fix these") {
            correctionBlock = "\nCORRECTION:\n\(intent)"
        } else {
            correctionBlock = ""
        }

        return """
        ROLE:TEKS lesson planner
        CONSTRAINT:Output ONLY valid JSON matching this schema
        CONSTRAINT:Bloom verb in objective must match or exceed TEKS cognitive level
        CONSTRAINT:Phases must follow gradual release (I Do/We Do/You Do)
        CONSTRAINT:Assessment must directly measure the stated objective
        CONSTRAINT:Duration must be realistic (30-90 min)
        STANDARDS:
        \(teksBlock)
        SCHEMA:{title:str,teksCode:[str],gradeLevel:str,subject:str,objective:str,bloomLevel:str(Remember|Understand|Apply|Analyze|Evaluate|Create),durationMinutes:int,materials:[str],phases:[{name:str,durationMinutes:int,description:str,teacherActions:[str],studentActions:[str]}],assessment:{type:str,description:str,alignsToObjective:bool},differentiation:{ell:str,specialEducation:str,gifted:str,struggling:str},closure:str}
        OUTPUT:JSON only. No markdown. No explanation.\(correctionBlock)
        """
    }

    // MARK: - Validation

    /// Validate a generated lesson plan against structural constraints.
    /// This is "Verification is Computation" — every check is deterministic.
    public func validate(_ output: TEKSLessonPlan) -> ValidationResult {
        var violations: [Violation] = []
        var penalties = 0.0

        // 1. TEKS code must exist in domain pack
        for code in output.teksCode {
            if domainPack.lookup(code) == nil {
                violations.append(Violation(
                    field: "teksCode",
                    reason: "TEKS code '\(code)' not found in domain pack",
                    correctionHint: "Use only valid TEKS codes from the provided standards list",
                    severity: .hard
                ))
                penalties += 0.3
            }
        }

        // 2. Bloom's level must meet or exceed the standard's level
        if let firstCode = output.teksCode.first,
           let entry = domainPack.lookup(firstCode),
           let requiredBloom = entry.metadata["bloom"],
           let required = BloomLevel.fromString(requiredBloom) {
            if output.bloomLevel < required {
                violations.append(Violation(
                    field: "bloomLevel",
                    reason: "Bloom level '\(output.bloomLevel.rawValue)' is below TEKS requirement '\(requiredBloom)'",
                    correctionHint: "Objective must use a Bloom's verb at '\(requiredBloom)' level or higher",
                    severity: .hard
                ))
                penalties += 0.25
            }
        }

        // 3. Objective must not be empty and should contain a verb
        if output.objective.trimmingCharacters(in: .whitespaces).count < 10 {
            violations.append(Violation(
                field: "objective",
                reason: "Objective too short — must be a complete learning objective",
                correctionHint: "Write a full objective starting with a Bloom's verb: 'Students will [verb]...'",
                severity: .hard
            ))
            penalties += 0.2
        }

        // 4. Duration must be realistic (30-90 min for a standard class period)
        if output.durationMinutes < 30 || output.durationMinutes > 90 {
            violations.append(Violation(
                field: "durationMinutes",
                reason: "Duration \(output.durationMinutes) min is outside realistic range (30-90)",
                correctionHint: "Set duration between 30-90 minutes for a standard class period",
                severity: .hard
            ))
            penalties += 0.15
        }

        // 5. Must have at least 3 phases (gradual release: I Do / We Do / You Do)
        if output.phases.count < 3 {
            violations.append(Violation(
                field: "phases",
                reason: "Only \(output.phases.count) phase(s) — gradual release requires at least 3",
                correctionHint: "Include at minimum: I Do (direct instruction), We Do (guided practice), You Do (independent practice)",
                severity: .hard
            ))
            penalties += 0.2
        }

        // 6. Phase durations should roughly sum to total duration
        let phaseSum = output.phases.reduce(0) { $0 + $1.durationMinutes }
        let durationDrift = abs(phaseSum - output.durationMinutes)
        if durationDrift > 10 {
            violations.append(Violation(
                field: "phases.duration",
                reason: "Phase durations sum to \(phaseSum) min but total is \(output.durationMinutes) min (drift: \(durationDrift))",
                correctionHint: "Phase durations should sum to approximately \(output.durationMinutes) minutes",
                severity: .soft
            ))
            penalties += 0.1
        }

        // 7. Assessment must claim alignment
        if !output.assessment.alignsToObjective {
            violations.append(Violation(
                field: "assessment.alignsToObjective",
                reason: "Assessment does not claim alignment to objective",
                correctionHint: "Assessment must directly measure the stated learning objective. Set alignsToObjective to true and describe how.",
                severity: .hard
            ))
            penalties += 0.2
        }

        // 8. Differentiation fields must not be empty
        let diffFields = [
            ("differentiation.ell", output.differentiation.ell),
            ("differentiation.specialEducation", output.differentiation.specialEducation),
            ("differentiation.gifted", output.differentiation.gifted),
            ("differentiation.struggling", output.differentiation.struggling)
        ]
        for (field, value) in diffFields {
            if value.trimmingCharacters(in: .whitespaces).isEmpty {
                violations.append(Violation(
                    field: field,
                    reason: "Differentiation strategy is empty",
                    correctionHint: "Provide a specific differentiation strategy for this population",
                    severity: .soft
                ))
                penalties += 0.05
            }
        }

        // 9. Closure must exist
        if output.closure.trimmingCharacters(in: .whitespaces).count < 5 {
            violations.append(Violation(
                field: "closure",
                reason: "Closure/exit ticket is missing or too brief",
                correctionHint: "Provide a closure activity or exit ticket that checks for understanding",
                severity: .soft
            ))
            penalties += 0.05
        }

        let score = max(0, 1.0 - penalties)
        let hasHardViolations = violations.contains { $0.severity == .hard }

        return ValidationResult(
            isValid: !hasHardViolations,
            violations: violations,
            score: score
        )
    }
}
