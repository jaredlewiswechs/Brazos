// MockBackend.swift
// Brazos — Mock Model Backend for Testing
//
// Deterministic. No network. No model. Just returns
// pre-configured responses so the Generator + Schema + Validator
// loop can be tested end-to-end without any external dependency.
//
// Also useful as a reference implementation for the ModelBackend protocol.

import Foundation
import Brazos

// MARK: - Mock Backend

/// A mock model backend that returns pre-configured responses.
/// Use for unit tests, UI previews, and offline development.
public struct MockBackend: ModelBackend {

    public let identifier = "mock-deterministic"
    public let contextWindow = 4096

    /// The responses this mock will return, in order.
    /// After exhausting the list, it cycles back to the first.
    private let responses: [String]
    private let latency: TimeInterval

    public init(responses: [String], latency: TimeInterval = 0.1) {
        self.responses = responses
        self.latency = latency
    }

    /// Convenience: single response that always returns the same thing.
    public init(response: String, latency: TimeInterval = 0.1) {
        self.responses = [response]
        self.latency = latency
    }

    private static var callCount = 0

    public func generate(_ request: GenerationRequest) async throws -> GenerationResponse {
        // Simulate latency
        try await Task.sleep(for: .milliseconds(Int(latency * 1000)))

        let index = MockBackend.callCount % responses.count
        MockBackend.callCount += 1

        let text = responses[index]
        let inputTokens = (request.systemPrompt.count + request.userPrompt.count) / 4
        let outputTokens = text.count / 4

        return GenerationResponse(
            text: text,
            usage: TokenUsage(input: inputTokens, output: outputTokens),
            elapsed: latency
        )
    }
}

// MARK: - Pre-built Mock Responses

public enum MockResponses {

    /// A valid TEKS lesson plan for M8.4A (slope)
    public static let validSlopeLessonJSON = """
    {
        "title": "Understanding Slope Through Similar Right Triangles",
        "teksCode": ["M8.4A"],
        "gradeLevel": "8",
        "subject": "Mathematics",
        "objective": "Students will explain how slope represents a constant rate of change by constructing similar right triangles on a coordinate plane and comparing the ratio of vertical to horizontal change.",
        "bloomLevel": "Understand",
        "durationMinutes": 50,
        "materials": [
            "Graph paper",
            "Rulers",
            "Colored pencils",
            "Slope discovery worksheet",
            "Projector"
        ],
        "phases": [
            {
                "name": "I Do",
                "durationMinutes": 12,
                "description": "Direct instruction: introduce slope as rise over run using a real-world ramp example",
                "teacherActions": [
                    "Display a wheelchair ramp diagram on projector",
                    "Draw two right triangles on the ramp at different points",
                    "Calculate rise/run for both triangles, show they are equal",
                    "Define slope as m = (y2-y1)/(x2-x1)"
                ],
                "studentActions": [
                    "Copy diagram and formula into notes",
                    "Predict whether the slope will be the same at different points"
                ]
            },
            {
                "name": "We Do",
                "durationMinutes": 18,
                "description": "Guided practice: students construct right triangles on graphed lines with partners",
                "teacherActions": [
                    "Distribute graph paper with pre-drawn lines",
                    "Guide students to pick two different pairs of points",
                    "Circulate and check triangle constructions",
                    "Lead class discussion: Did everyone get the same slope?"
                ],
                "studentActions": [
                    "Draw right triangles between different point pairs on the same line",
                    "Calculate slope for each triangle pair",
                    "Compare results with partner",
                    "Record observations on worksheet"
                ]
            },
            {
                "name": "You Do",
                "durationMinutes": 15,
                "description": "Independent practice: slope calculation from coordinate pairs",
                "teacherActions": [
                    "Monitor progress and provide individual feedback",
                    "Identify common errors for whole-class correction"
                ],
                "studentActions": [
                    "Complete 6 slope problems independently",
                    "For each: plot points, draw right triangle, calculate slope",
                    "Write one sentence explaining what the slope means in context"
                ]
            }
        ],
        "assessment": {
            "type": "formative",
            "description": "Exit ticket: Given points (2,3) and (6,11), find the slope. Draw the right triangle. Explain in one sentence why the slope is the same no matter which two points you choose on the line.",
            "alignsToObjective": true
        },
        "differentiation": {
            "ell": "Bilingual vocabulary card with visual: slope, rise, run, right triangle. Sentence frame for explanation: 'The slope is ___ because the rise is ___ and the run is ___.'",
            "specialEducation": "Pre-drawn coordinate planes with labeled axes. Graphic organizer breaking slope formula into steps. Reduced problem set (4 instead of 6).",
            "gifted": "Extension: Given three points, determine if they are collinear using slope. Investigate what happens to the triangle when the line is vertical.",
            "struggling": "Color-coded rise (red) and run (blue) on graph paper. Start with integer coordinates only. Pair with a peer tutor for We Do phase."
        },
        "closure": "Exit ticket: Find the slope between (2,3) and (6,11) using a right triangle. Write one sentence: Why does slope stay the same between any two points on the same line?"
    }
    """

    /// A lesson plan with Bloom's level too low (will fail validation)
    public static let lowBloomLessonJSON = """
    {
        "title": "Slope Definitions",
        "teksCode": ["M8.4A"],
        "gradeLevel": "8",
        "subject": "Mathematics",
        "objective": "Students will list the definition of slope and identify the formula.",
        "bloomLevel": "Remember",
        "durationMinutes": 50,
        "materials": ["Textbook", "Whiteboard"],
        "phases": [
            {
                "name": "I Do",
                "durationMinutes": 25,
                "description": "Lecture on slope definition",
                "teacherActions": ["Present definition"],
                "studentActions": ["Copy notes"]
            },
            {
                "name": "You Do",
                "durationMinutes": 25,
                "description": "Worksheet",
                "teacherActions": ["Monitor"],
                "studentActions": ["Complete worksheet"]
            }
        ],
        "assessment": {
            "type": "formative",
            "description": "Vocabulary quiz",
            "alignsToObjective": true
        },
        "differentiation": {
            "ell": "Word wall",
            "specialEducation": "Reduced set",
            "gifted": "Extra problems",
            "struggling": "Peer help"
        },
        "closure": "Review"
    }
    """

    /// Malformed JSON (will trigger decode retry)
    public static let malformedJSON = """
    Sure! Here's a lesson plan for slope:
    {title: "Slope Lesson", teksCode: ["M8.4A"]
    """
}
