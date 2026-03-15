// TEKSDomainPack.swift
// BrazosTEKS — TEKS Domain Pack for Brazos
//
// First domain pack. Texas Essential Knowledge and Skills.
// This is the domain Jared knows deeper than anyone building
// AI tools for education — 16 months teaching CS and humanities
// at Worthing, plus an M.S. in Curriculum and Instruction.
//
// The pack provides TEKS standards as structured data that the
// TEKSLessonSchema can compress into structural prompts.

import Foundation
import Brazos

// MARK: - TEKS Domain Pack

public struct TEKSDomainPack: DomainPack {

    public let domainID = "teks-2024"
    public let displayName = "Texas Essential Knowledge and Skills"
    public let version = "2024.1"

    private let entries: [DomainEntry]

    public init(entries: [DomainEntry] = TEKSDomainPack.defaultEntries()) {
        self.entries = entries
    }

    public func lookup(_ code: String) -> DomainEntry? {
        entries.first { $0.code.lowercased() == code.lowercased() }
    }

    public func query(filter: DomainFilter) -> [DomainEntry] {
        entries.filter { entry in
            if let category = filter.category,
               !entry.category.lowercased().contains(category.lowercased()) {
                return false
            }
            if let scope = filter.scope,
               !entry.scope.lowercased().contains(scope.lowercased()) {
                return false
            }
            if let codes = filter.codes,
               !codes.contains(where: { entry.code.lowercased().contains($0.lowercased()) }) {
                return false
            }
            if let search = filter.search,
               !entry.content.lowercased().contains(search.lowercased()) &&
               !entry.title.lowercased().contains(search.lowercased()) {
                return false
            }
            return true
        }
    }

    /// Compress matching entries into a prompt-ready string.
    /// Every token counts on a 4K window. This outputs the tightest
    /// possible representation of the relevant standards.
    public func compress(filter: DomainFilter) -> String {
        let matching = query(filter: filter)
        if matching.isEmpty { return "[NO MATCHING TEKS]" }

        // Compressed format: one line per standard
        // CODE|TITLE|BLOOM|CONTENT(truncated)
        let lines = matching.map { entry in
            let bloom = entry.metadata["bloom"] ?? "?"
            let truncated = String(entry.content.prefix(120))
            return "\(entry.code)|\(entry.title)|\(bloom)|\(truncated)"
        }

        return """
        TEKS|\(matching.count) standards|\(matching.first?.scope ?? "")
        \(lines.joined(separator: "\n"))
        """
    }

    // MARK: - Seed Data

    /// Starter set of TEKS entries. In production this loads from
    /// a JSON bundle. For now, seed with CS and Math standards
    /// Jared knows by heart.
    public static func defaultEntries() -> [DomainEntry] {
        [
            // Fundamentals of CS (CodeHS Texas course)
            DomainEntry(
                code: "FCS.1A",
                title: "Creativity and Innovation",
                content: "The student demonstrates creative thinking, constructs knowledge, and develops innovative products and processes using technology.",
                category: "Fundamentals of Computer Science",
                scope: "High School",
                metadata: ["bloom": "Create", "strand": "Creativity"]
            ),
            DomainEntry(
                code: "FCS.2A",
                title: "Communication and Collaboration",
                content: "The student uses digital media and environments to communicate and work collaboratively, including at a distance, to support individual learning and contribute to the learning of others.",
                category: "Fundamentals of Computer Science",
                scope: "High School",
                metadata: ["bloom": "Apply", "strand": "Communication"]
            ),
            DomainEntry(
                code: "FCS.3A",
                title: "Research and Information Fluency",
                content: "The student applies digital tools to gather, evaluate, and use information.",
                category: "Fundamentals of Computer Science",
                scope: "High School",
                metadata: ["bloom": "Analyze", "strand": "Research"]
            ),
            DomainEntry(
                code: "FCS.4A",
                title: "Critical Thinking and Problem Solving",
                content: "The student uses critical thinking skills to plan and conduct research, manage projects, solve problems, and make informed decisions using appropriate digital tools and resources.",
                category: "Fundamentals of Computer Science",
                scope: "High School",
                metadata: ["bloom": "Evaluate", "strand": "Critical Thinking"]
            ),
            DomainEntry(
                code: "FCS.5A",
                title: "Digital Citizenship",
                content: "The student understands human, cultural, and societal issues related to technology and practices legal and ethical behavior.",
                category: "Fundamentals of Computer Science",
                scope: "High School",
                metadata: ["bloom": "Understand", "strand": "Ethics"]
            ),

            // Math Grade 8 — selected standards
            DomainEntry(
                code: "M8.1A",
                title: "Mathematical Process Standards",
                content: "Apply mathematics to problems arising in everyday life, society, and the workplace.",
                category: "Mathematics",
                scope: "Grade 8",
                metadata: ["bloom": "Apply", "strand": "Process"]
            ),
            DomainEntry(
                code: "M8.2A",
                title: "Number and Operations — Rational",
                content: "Extend previous knowledge of sets and subsets using a visual representation to describe relationships between sets of real numbers.",
                category: "Mathematics",
                scope: "Grade 8",
                metadata: ["bloom": "Understand", "strand": "Number"]
            ),
            DomainEntry(
                code: "M8.4A",
                title: "Proportionality — Slope",
                content: "Use similar right triangles to develop an understanding that slope, m, given as the rate comparing the change in y-values to the change in x-values, (y2-y1)/(x2-x1), is the same for any two points (x1,y1) and (x2,y2) on the same line.",
                category: "Mathematics",
                scope: "Grade 8",
                metadata: ["bloom": "Understand", "strand": "Proportionality"]
            ),
            DomainEntry(
                code: "M8.5A",
                title: "Linear Relationships — Proportional",
                content: "Represent linear proportional situations with tables, graphs, and equations in the form of y=kx.",
                category: "Mathematics",
                scope: "Grade 8",
                metadata: ["bloom": "Apply", "strand": "Linear"]
            ),
            DomainEntry(
                code: "M8.8A",
                title: "Expressions and Equations — Scientific Notation",
                content: "Write one-variable equations or inequalities with variables on both sides that represent problems using rational number coefficients and constants.",
                category: "Mathematics",
                scope: "Grade 8",
                metadata: ["bloom": "Apply", "strand": "Equations"]
            ),

            // ELA Grade 8 — selected
            DomainEntry(
                code: "ELA8.5A",
                title: "Comprehension — Inference",
                content: "Establish purpose for reading assigned and self-selected texts. Make and correct or confirm predictions using text features, characteristics of genre, and structures.",
                category: "English Language Arts",
                scope: "Grade 8",
                metadata: ["bloom": "Analyze", "strand": "Comprehension"]
            ),
            DomainEntry(
                code: "ELA8.10A",
                title: "Composition — Writing Process",
                content: "Plan a first draft by selecting a genre appropriate for a particular topic, purpose, and audience using a range of strategies such as discussion, background reading, and personal interests.",
                category: "English Language Arts",
                scope: "Grade 8",
                metadata: ["bloom": "Create", "strand": "Composition"]
            ),
        ]
    }
}
