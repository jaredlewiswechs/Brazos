// LessonPlannerViewModel.swift
// Brazos Lesson Planner

import SwiftUI
import Observation
import Brazos
import BrazosTEKS

@Observable
@MainActor
final class LessonPlannerViewModel {

    // MARK: - Input State

    var subject: String = "Mathematics"
    var gradeLevel: String = "8"
    var teksCode: String = ""
    var userIntent: String = ""
    var backendMode: BackendMode = .apple

    // MARK: - Output State

    var currentPlan: TEKSLessonPlan?
    var lastLedger: GenerationLedger<TEKSLessonPlan>?
    var isGenerating: Bool = false
    var errorMessage: String?

    // MARK: - Engine

    private let domainPack = TEKSDomainPack()

    // MARK: - TEKS Lookup

    func lookupTEKS() -> DomainEntry? {
        guard !teksCode.isEmpty else { return nil }
        return domainPack.lookup(teksCode)
    }

    // MARK: - Generate

    func generate() async {
        isGenerating = true
        errorMessage = nil
        currentPlan = nil
        lastLedger = nil

        let schema = TEKSLessonSchema(domainPack: domainPack)
        let backend = resolveBackend()
        let generator = Generator(schema: schema, backend: backend)

        var params: [String: String] = [
            "subject": subject,
            "gradeLevel": gradeLevel
        ]

        // Only pass TEKS code if non-empty
        let trimmedCode = teksCode.trimmingCharacters(in: .whitespaces)
        if !trimmedCode.isEmpty {
            params["teksCode"] = trimmedCode
        }

        let context = SchemaContext(
            parameters: params,
            userIntent: userIntent.isEmpty ? nil : userIntent
        )

        do {
            let ledger = try await generator.generate(context: context)
            self.lastLedger = ledger
            self.currentPlan = ledger.finalOutput

            if ledger.status == .failed {
                errorMessage = "Generation failed after \(ledger.attemptCount) attempts."
            } else if ledger.status == .exhausted {
                errorMessage = "Best effort after \(ledger.attemptCount) attempts. Some constraints may not be met."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Backend Resolution

    private func resolveBackend() -> any ModelBackend {
        switch backendMode {
        case .apple:
            return AppleFoundationBackend()
        case .claude:
            // In production, pull from Keychain or environment
            let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
            if key.isEmpty {
                // Fall back to mock if no key configured
                return MockBackend(response: MockResponses.validSlopeLessonJSON)
            }
            return ClaudeBackend(apiKey: key)
        }
    }
}

// MARK: - Backend Mode

enum BackendMode {
    case apple
    case claude

    var label: String {
        switch self {
        case .apple: return "On-Device"
        case .claude: return "Claude"
        }
    }

    var icon: String {
        switch self {
        case .apple: return "iphone"
        case .claude: return "cloud"
        }
    }
}
