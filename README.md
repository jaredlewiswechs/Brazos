# Brazos

**Form-constrained generation engine.**

A Swift Package that takes formal boundaries from any domain — TEKS standards, building codes, curriculum sequences — and turns a small, fast, private model into a structurally correct generator. If output doesn't fit the form, it doesn't exist.

## Thesis

The 4K context window isn't a limitation. It's a forcing function. If the constraint schema is tight enough, 4K is abundant. The model doesn't reason through possibilities — it fills a mold.

> Form creates form, form recognizes form. Intelligence lies within the structure, not the function.

## Architecture

```
┌─────────────────────────────────────────┐
│              Consumer App               │
│  (Lesson Planner, SiteOS, DIL tool)     │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│               Brazos                     │
│                                          │
│  ConstraintSchema ─── defines the form   │
│  Generator ────────── fills the form     │
│  Validator ────────── verifies the form  │
│  DomainPack ───────── provides the data  │
│  ModelBackend ─────── talks to the model │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   Apple FM    Claude API   Local
   (4K, fast,  (200K,       (GGUF,
    private)    powerful)    offline)
```

## PARCRI Invariants

Every component obeys all five:

1. **Diffs only** — Retry targets failed fields, not the whole output
2. **Intent first** — Schema encodes what output means, not how to make it
3. **Compress to learn** — Schema IS the compression of domain knowledge
4. **Boundary on recursion** — Max retries are hard-coded in the schema
5. **Reversible state** — Every generation attempt is a value in an immutable ledger

## Domain Packs

| Pack | Status | Domain |
|------|--------|--------|
| `BrazosTEKS` | Active | Texas Essential Knowledge and Skills |
| Building Codes | Planned | IRC residential exempt structures |
| DIL Curriculum | Planned | Data Integrated Learning S400-S700 |

## Ship Plan

1. **Now**: TEKS domain pack + lesson plan schema → lesson planning iOS app
2. **Next**: Building code pack → Lewis Built / SiteOS exempt drawings
3. **After**: DIL pack → curriculum licensing for TPT / microschools
4. **Always**: The engine is domain-agnostic. New pack = new market.

## Usage

```swift
import Brazos
import BrazosTEKS

// Set up
let pack = TEKSDomainPack()
let schema = TEKSLessonSchema(domainPack: pack)
let backend = AppleFoundationModelBackend() // or ClaudeBackend()
let generator = Generator(schema: schema, backend: backend)

// Generate a TEKS-aligned lesson plan
let context = SchemaContext(parameters: [
    "subject": "Mathematics",
    "gradeLevel": "8",
    "teksCode": "M8.4A"
], userIntent: "Focus on hands-on activities with real-world slope examples")

let ledger = try await generator.generate(context: context)

if let plan = ledger.finalOutput {
    print(plan.title)           // Structurally valid
    print(plan.objective)       // Bloom's level verified
    print(plan.phases.count)    // Gradual release enforced
    print(ledger.totalTokens)   // Prove the compression thesis
}
```

## License

Copyright © 2026 Jared Lewis / PARCRI. All rights reserved.

## Research Foundation

See [BIBLIOGRAPHY.md](BIBLIOGRAPHY.md) for the complete body of prior work.
