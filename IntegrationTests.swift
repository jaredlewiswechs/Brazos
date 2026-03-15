// IntegrationTests.swift
// End-to-end tests for the Brazos generation loop

import Testing
@testable import Brazos
@testable import BrazosTEKS

// MARK: - Full Generation Loop

@Test("Full generation loop produces valid lesson plan")
func testFullGenerationLoop() async throws {
    let pack = TEKSDomainPack()
    let schema = TEKSLessonSchema(domainPack: pack)
    let backend = MockBackend(response: MockResponses.validSlopeLessonJSON)
    let generator = Generator(schema: schema, backend: backend)

    let context = SchemaContext(parameters: [
        "subject": "Mathematics",
        "gradeLevel": "8",
        "teksCode": "M8.4A"
    ], userIntent: "Focus on hands-on activities")

    let ledger = try await generator.generate(context: context)

    // Should succeed on first attempt
    #expect(ledger.status == .valid)
    #expect(ledger.attemptCount == 1)
    #expect(ledger.finalOutput != nil)

    let plan = ledger.finalOutput!
    #expect(plan.teksCode.contains("M8.4A"))
    #expect(plan.bloomLevel >= .understand) // M8.4A requires Understand
    #expect(plan.phases.count >= 3) // gradual release
    #expect(plan.assessment.alignsToObjective)
    #expect(plan.durationMinutes >= 15 && plan.durationMinutes <= 120)

    // Compression ratio check — the thesis
    if let tokens = ledger.totalTokens {
        let ratio = tokens.compressionRatio(windowSize: 4096)
        // Structural prompt + user prompt should use well under 40% of 4K
        #expect(ratio < 0.5, "Compression ratio \(ratio) exceeds 50% of context window")
    }
}

@Test("Low Bloom level triggers retry")
func testBloomRetryLoop() async throws {
    let pack = TEKSDomainPack()
    let schema = TEKSLessonSchema(domainPack: pack)

    // First response has low Bloom, second is valid
    let backend = MockBackend(responses: [
        MockResponses.lowBloomLessonJSON,
        MockResponses.validSlopeLessonJSON
    ])
    let generator = Generator(schema: schema, backend: backend)

    let context = SchemaContext(parameters: [
        "subject": "Mathematics",
        "gradeLevel": "8",
        "teksCode": "M8.4A"
    ])

    let ledger = try await generator.generate(context: context)

    // Should have taken 2 attempts
    #expect(ledger.attemptCount == 2)
    #expect(ledger.status == .valid)

    // First attempt should have Bloom violation
    let firstEntry = ledger.entries[0]
    #expect(firstEntry.validation?.isValid == false)
    #expect(firstEntry.validation?.violations.contains { $0.field == "bloomLevel" } == true)

    // Final output should be valid
    #expect(ledger.finalOutput?.bloomLevel == .understand)
}

@Test("Malformed JSON triggers decode retry")
func testDecodeRetry() async throws {
    let pack = TEKSDomainPack()
    let schema = TEKSLessonSchema(domainPack: pack)

    // First response is garbage, second is valid
    let backend = MockBackend(responses: [
        MockResponses.malformedJSON,
        MockResponses.validSlopeLessonJSON
    ])
    let generator = Generator(schema: schema, backend: backend)

    let context = SchemaContext(parameters: [
        "subject": "Mathematics",
        "gradeLevel": "8",
        "teksCode": "M8.4A"
    ])

    let ledger = try await generator.generate(context: context)

    // First attempt should be a decode error
    let firstEntry = ledger.entries[0]
    #expect(firstEntry.error != nil)
    #expect(firstEntry.output == nil)

    // Should recover on second attempt
    #expect(ledger.finalOutput != nil)
    #expect(ledger.attemptCount == 2)
}

@Test("Structural prompt fits in 4K budget")
func testPromptFits4K() {
    let pack = TEKSDomainPack()
    let schema = TEKSLessonSchema(domainPack: pack)

    let context = SchemaContext(parameters: [
        "subject": "Mathematics",
        "gradeLevel": "8",
        "teksCode": "M8.4A"
    ], userIntent: "Focus on hands-on activities with real-world slope examples")

    let prompt = schema.structuralPrompt(context: context)

    // Rough token estimate: ~4 chars per token
    let estimatedTokens = prompt.count / 4

    // Structural prompt should be well under 1000 tokens
    // leaving 3000+ tokens for generation
    #expect(estimatedTokens < 1000, "Structural prompt uses ~\(estimatedTokens) tokens — too large for 4K window")

    // Verify it contains the key structural elements
    #expect(prompt.contains("CONSTRAINT"))
    #expect(prompt.contains("SCHEMA"))
    #expect(prompt.contains("M8.4A"))
}

@Test("Domain pack compression is tight")
func testCompressionTightness() {
    let pack = TEKSDomainPack()

    // Compress all math standards
    let mathCompressed = pack.compress(filter: DomainFilter(category: "Mathematics"))
    let mathTokens = mathCompressed.count / 4

    // All CS standards
    let csCompressed = pack.compress(filter: DomainFilter(category: "Fundamentals"))
    let csTokens = csCompressed.count / 4

    // Each subject's compressed standards should fit in a few hundred tokens
    #expect(mathTokens < 500, "Math standards compressed to ~\(mathTokens) tokens — too large")
    #expect(csTokens < 500, "CS standards compressed to ~\(csTokens) tokens — too large")
}
