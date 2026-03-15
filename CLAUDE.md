# CLAUDE.md — Brazos

## What is Brazos?

Brazos is a form-constrained generation engine. A Swift Package that takes formal boundaries from any domain (TEKS standards, building codes, curriculum sequences) and turns a small, private, on-device AI model into a structurally correct generator.

**Core thesis**: The 4K context window on Apple Foundation Models is not a limitation — it's a forcing function. If the constraint schema is tight enough, 4K is abundant. The model fills a mold, it doesn't explore possibilities.

**Creator**: Jared Lewis / PARCRI. Former K-12 teacher (CS + humanities), current M.S. Curriculum & Instruction candidate (WGU, May 2026). Deep expertise in Texas TEKS standards. Two years of prior research (Newton, Ada, THIA, Shape Theory, "Verification is Computation," etc.) — all foundational. Brazos is the substrate.

## Architecture

```
ConstraintSchema (protocol) — defines the shape of valid output
    → structuralPrompt(context:) — compressed form for the model
    → validate(_:) — "Verification is Computation" at runtime

ModelBackend (protocol) — abstraction over any LLM
    → AppleFoundationBackend — 4K, on-device, private, free
    → ClaudeBackend — 200K, remote, powerful
    → MockBackend — deterministic, for tests

Generator<Schema> — the harness
    → schema + backend + validation loop = constrained generation
    → produces a GenerationLedger (immutable, replayable)

DomainPack (protocol) — pluggable domain knowledge
    → TEKSDomainPack — first pack (Texas education standards)
    → compress(filter:) — tight representation for prompt budget
```

## PARCRI Invariants (must obey all five)

1. **Diffs only** — retry targets failed fields, not the whole output
2. **Intent first** — schema encodes what, not how
3. **Compress to learn** — schema IS compression of domain knowledge
4. **Boundary on recursion** — maxRetries is hard-coded
5. **Reversible state** — every attempt is a value in an immutable ledger

## Rules for Claude

- Never generate code that violates the five invariants
- The Generator must remain stateless — it produces ledgers, never mutates
- ConstraintSchema.validate() must be deterministic — no randomness, no model calls
- Structural prompts must be tight — measure token estimates, stay under 1000 tokens
- Every model interaction goes through the ModelBackend protocol — no direct API calls
- Output types must be Codable & Sendable — always serializable, always thread-safe
- Test everything with MockBackend first, real backends second
- When in doubt about Swift conventions: protocol-oriented, value types, structured concurrency

## File Layout

```
brazos/
  Package.swift
  Sources/
    Brazos/                    # Core engine (domain-agnostic)
      ConstraintSchema.swift
      Generator.swift
      ModelBackend.swift
      DomainPack.swift
      AppleFoundationBackend.swift
      ClaudeBackend.swift
      Brazos.swift             # Umbrella
    BrazosTEKS/                # First domain pack
      TEKSDomainPack.swift
      TEKSLessonSchema.swift
      MockBackend.swift
  Tests/
    BrazosTests/
      BrazosTests.swift
      IntegrationTests.swift
```

## Current Domain Packs

| Pack | Target | Status |
|------|--------|--------|
| BrazosTEKS | Lesson planning iOS app | Active |
| Building Codes | Lewis Built / SiteOS | Planned |
| DIL Curriculum | TPT / microschool licensing | Planned |

## Ship Target

iOS app: Brazos Lesson Planner
- SwiftUI, iOS 26+
- Imports Brazos + BrazosTEKS as local Swift Package
- On-device generation via Apple Foundation Models (default)
- Claude API fallback for development/testing
- Revenue: App Store, paid
