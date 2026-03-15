// DomainPack.swift
// Brazos — Form-Constrained Generation Engine
//
// A DomainPack is a bundle of domain knowledge compressed into
// a form that ConstraintSchemas can consume. TEKS standards,
// building codes, curriculum sequences — all are domain packs.
//
// The pack doesn't generate anything. It provides the raw material
// that a schema shapes into constraints.

import Foundation

// MARK: - Domain Pack Protocol

/// A DomainPack provides domain-specific knowledge to a ConstraintSchema.
///
/// Think of it as the dataset behind the form:
/// - TEKS pack: standards, grade bands, subject codes, Bloom's mappings
/// - Building code pack: IRC sections, exempt structure rules, setback tables
/// - Curriculum pack: scope sequences, pacing guides, assessment frameworks
///
/// Domain packs are pure data. No generation logic. No model calls.
/// They answer the question: "What does this domain require?"
public protocol DomainPack: Sendable {

    /// Unique identifier for this domain.
    /// e.g. "teks-2024", "irc-2021", "dil-s400"
    var domainID: String { get }

    /// Human-readable name.
    var displayName: String { get }

    /// Version string. Domain packs should be versioned because
    /// standards change (TEKS updates, code amendments, etc.)
    var version: String { get }

    /// Look up a specific standard or constraint by its code.
    /// e.g. "8.1A" returns the TEKS standard for Math 8, expectation 1A
    ///
    /// Returns nil if the code doesn't exist in this domain.
    func lookup(_ code: String) -> DomainEntry?

    /// Return all entries matching a filter.
    /// e.g. all Math standards for grade 8, all IRC sections for residential exempt
    func query(filter: DomainFilter) -> [DomainEntry]

    /// Compress this domain's relevant entries into a prompt-ready string.
    /// This is where "compress to learn" happens at the domain level.
    /// The output should be as tight as possible — every token counts
    /// when you're targeting a 4K window.
    ///
    /// - Parameter filter: Which subset of the domain to compress
    /// - Returns: A compressed string representation
    func compress(filter: DomainFilter) -> String
}

// MARK: - Domain Entry

/// A single entry in a domain pack.
/// Could be a TEKS standard, a building code section, a curriculum unit, etc.
public struct DomainEntry: Sendable, Codable {

    /// The standard/section/unit code.
    /// e.g. "8.1A", "IRC R301.2", "S400.Unit3"
    public let code: String

    /// Short title or description.
    public let title: String

    /// Full text of the standard/requirement.
    public let content: String

    /// Category or grouping.
    /// e.g. "Number and Operations", "Structural Design", "Data Literacy"
    public let category: String

    /// Grade level, complexity tier, or applicability scope.
    public let scope: String

    /// Additional metadata as key-value pairs.
    public let metadata: [String: String]

    public init(
        code: String,
        title: String,
        content: String,
        category: String,
        scope: String,
        metadata: [String: String] = [:]
    ) {
        self.code = code
        self.title = title
        self.content = content
        self.category = category
        self.scope = scope
        self.metadata = metadata
    }
}

// MARK: - Domain Filter

/// Filter criteria for querying a domain pack.
public struct DomainFilter: Sendable {

    /// Filter by category (e.g. subject area, code chapter)
    public let category: String?

    /// Filter by scope (e.g. grade level, building type)
    public let scope: String?

    /// Filter by specific codes
    public let codes: [String]?

    /// Free-text search within content
    public let search: String?

    public init(
        category: String? = nil,
        scope: String? = nil,
        codes: [String]? = nil,
        search: String? = nil
    ) {
        self.category = category
        self.scope = scope
        self.codes = codes
        self.search = search
    }

    /// No filter — return everything.
    public static let all = DomainFilter()
}
