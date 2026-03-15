// BrazosTests.swift
// Tests for Brazos core + TEKS domain pack

import Testing
@testable import Brazos
@testable import BrazosTEKS

// MARK: - Domain Pack Tests

@Test("TEKS pack lookup finds valid codes")
func testTEKSLookup() {
    let pack = TEKSDomainPack()
    let entry = pack.lookup("M8.4A")
    #expect(entry != nil)
    #expect(entry?.title == "Proportionality — Slope")
    #expect(entry?.metadata["bloom"] == "Understand")
}

@Test("TEKS pack lookup returns nil for invalid codes")
func testTEKSLookupMissing() {
    let pack = TEKSDomainPack()
    #expect(pack.lookup("FAKE.99Z") == nil)
}

@Test("TEKS pack query filters by category")
func testTEKSQueryCategory() {
    let pack = TEKSDomainPack()
    let results = pack.query(filter: DomainFilter(category: "Mathematics"))
    #expect(results.count > 0)
    #expect(results.allSatisfy { $0.category == "Mathematics" })
}

@Test("TEKS pack query filters by scope")
func testTEKSQueryScope() {
    let pack = TEKSDomainPack()
    let results = pack.query(filter: DomainFilter(scope: "Grade 8"))
    #expect(results.count > 0)
    #expect(results.allSatisfy { $0.scope == "Grade 8" })
}

@Test("TEKS compress produces tight output")
func testTEKSCompress() {
    let pack = TEKSDomainPack()
    let compressed = pack.compress(filter: DomainFilter(category: "Mathematics"))
    #expect(compressed.contains("TEKS|"))
    #expect(compressed.contains("M8.4A"))
    // Compression should be tight — under 1000 chars for a few standards
    #expect(compressed.count < 1500)
}

// MARK: - Bloom Level Tests

@Test("Bloom levels compare correctly")
func testBloomComparison() {
    #expect(BloomLevel.remember < BloomLevel.understand)
    #expect(BloomLevel.apply < BloomLevel.analyze)
    #expect(BloomLevel.evaluate < BloomLevel.create)
    #expect(!(BloomLevel.create < BloomLevel.remember))
}

@Test("Bloom fromString maps common verbs")
func testBloomFromString() {
    #expect(BloomLevel.fromString("Apply") == .apply)
    #expect(BloomLevel.fromString("solve") == .apply)
    #expect(BloomLevel.fromString("design") == .create)
    #expect(BloomLevel.fromString("compare") == .analyze)
}

// MARK: - Schema Validation Tests

@Test("Valid lesson plan passes validation")
func testValidPlan() {
    let schema = TEKSLessonSchema()
    let plan = TEKSLessonPlan(
        title: "Understanding Slope with Real-World Examples",
        teksCode: ["M8.4A"],
        gradeLevel: "8",
        subject: "Mathematics",
        objective: "Students will explain how slope represents rate of change using similar right triangles and real-world scenarios",
        bloomLevel: .understand,
        durationMinutes: 50,
        materials: ["Graph paper", "Rulers", "Slope activity worksheet"],
        phases: [
            LessonPhase(name: "I Do", durationMinutes: 12,
                       description: "Direct instruction on slope concept",
                       teacherActions: ["Model slope calculation with right triangles"],
                       studentActions: ["Observe and take notes"]),
            LessonPhase(name: "We Do", durationMinutes: 18,
                       description: "Guided practice with partner",
                       teacherActions: ["Circulate and check understanding"],
                       studentActions: ["Calculate slope from graphs with partner"]),
            LessonPhase(name: "You Do", durationMinutes: 15,
                       description: "Independent practice",
                       teacherActions: ["Monitor and provide feedback"],
                       studentActions: ["Complete slope problems independently"])
        ],
        assessment: Assessment(type: "formative", description: "Exit ticket: calculate slope from two points and explain meaning", alignsToObjective: true),
        differentiation: Differentiation(
            ell: "Visual slope models, bilingual vocabulary cards",
            specialEducation: "Graphic organizer for slope steps, reduced problem set",
            gifted: "Extension: derive slope-intercept form from two points",
            struggling: "Pre-made right triangles on graph paper, peer tutoring"
        ),
        closure: "Exit ticket: Given two points, find the slope and write one sentence explaining what the slope tells you about the real-world situation."
    )

    let result = schema.validate(plan)
    #expect(result.isValid)
    #expect(result.violations.isEmpty)
    #expect(result.score == 1.0)
}

@Test("Invalid Bloom level triggers violation")
func testBloomViolation() {
    let schema = TEKSLessonSchema()
    // M8.4A requires "Understand" but we set "Remember"
    let plan = TEKSLessonPlan(
        title: "Slope Lesson",
        teksCode: ["M8.4A"],
        gradeLevel: "8",
        subject: "Mathematics",
        objective: "Students will list the definition of slope",
        bloomLevel: .remember, // TOO LOW — M8.4A requires Understand
        durationMinutes: 50,
        materials: ["Textbook"],
        phases: [
            LessonPhase(name: "I Do", durationMinutes: 20, description: "Lecture", teacherActions: ["Talk"], studentActions: ["Listen"]),
            LessonPhase(name: "We Do", durationMinutes: 15, description: "Practice", teacherActions: ["Help"], studentActions: ["Work"]),
            LessonPhase(name: "You Do", durationMinutes: 15, description: "Independent", teacherActions: ["Monitor"], studentActions: ["Work alone"])
        ],
        assessment: Assessment(type: "formative", description: "Quiz", alignsToObjective: true),
        differentiation: Differentiation(ell: "Vocabulary support", specialEducation: "Modified work", gifted: "Extension", struggling: "Peer help"),
        closure: "Review key terms"
    )

    let result = schema.validate(plan)
    #expect(!result.isValid)
    #expect(result.violations.contains { $0.field == "bloomLevel" })
}

@Test("Fake TEKS code triggers violation")
func testFakeTEKS() {
    let schema = TEKSLessonSchema()
    let plan = TEKSLessonPlan(
        title: "Fake Lesson",
        teksCode: ["FAKE.99Z"],
        gradeLevel: "8",
        subject: "Nothing",
        objective: "Students will demonstrate understanding of fake concepts through applied analysis",
        bloomLevel: .apply,
        durationMinutes: 50,
        materials: ["None"],
        phases: [
            LessonPhase(name: "I Do", durationMinutes: 15, description: "Intro", teacherActions: ["Teach"], studentActions: ["Learn"]),
            LessonPhase(name: "We Do", durationMinutes: 20, description: "Practice", teacherActions: ["Guide"], studentActions: ["Practice"]),
            LessonPhase(name: "You Do", durationMinutes: 15, description: "Solo", teacherActions: ["Monitor"], studentActions: ["Work"])
        ],
        assessment: Assessment(type: "formative", description: "Check", alignsToObjective: true),
        differentiation: Differentiation(ell: "Support", specialEducation: "Modified", gifted: "Extended", struggling: "Scaffolded"),
        closure: "Wrap up and review"
    )

    let result = schema.validate(plan)
    #expect(!result.isValid)
    #expect(result.violations.contains { $0.field == "teksCode" })
}

// MARK: - Ledger Tests

@Test("Generation ledger tracks attempts")
func testLedgerTracking() {
    var ledger = GenerationLedger<TEKSLessonPlan>(schemaName: "TEKS Lesson Plan")
    #expect(ledger.attemptCount == 0)
    #expect(ledger.status == .pending)

    ledger.record(
        attempt: 0,
        raw: "{}",
        output: nil,
        validation: nil,
        error: .decodingFailure("{}"),
        usage: TokenUsage(input: 200, output: 50)
    )

    #expect(ledger.attemptCount == 1)
    #expect(ledger.totalTokens?.total == 250)
}

// MARK: - Compression Ratio Tests

@Test("Token usage compression ratio calculation")
func testCompressionRatio() {
    let usage = TokenUsage(input: 800, output: 400)
    let ratio = usage.compressionRatio(windowSize: 4096)
    // 800 / 4096 ≈ 0.195 — well under 0.4 threshold
    #expect(ratio < 0.4)
    #expect(ratio > 0.1)
}
