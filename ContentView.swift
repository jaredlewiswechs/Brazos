// ContentView.swift
// Brazos Lesson Planner

import SwiftUI
import Brazos
import BrazosTEKS

struct ContentView: View {
    @State private var viewModel = LessonPlannerViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Input Section
                    InputSection(viewModel: viewModel)

                    // Generate Button
                    GenerateButton(viewModel: viewModel)

                    // Results
                    if let plan = viewModel.currentPlan {
                        LessonPlanView(plan: plan, ledger: viewModel.lastLedger)
                    }

                    // Ledger Stats (debug/proof)
                    if let ledger = viewModel.lastLedger {
                        LedgerStatsView(ledger: ledger)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Brazos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("On-Device (Apple FM)") { viewModel.backendMode = .apple }
                        Button("Claude API") { viewModel.backendMode = .claude }
                    } label: {
                        Label(viewModel.backendMode.label, systemImage: viewModel.backendMode.icon)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Input Section

struct InputSection: View {
    @Bindable var viewModel: LessonPlannerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Subject Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("SUBJECT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Picker("Subject", selection: $viewModel.subject) {
                    Text("Mathematics").tag("Mathematics")
                    Text("English Language Arts").tag("English Language Arts")
                    Text("Fundamentals of CS").tag("Fundamentals of Computer Science")
                    Text("Science").tag("Science")
                }
                .pickerStyle(.segmented)
            }

            // Grade Level
            VStack(alignment: .leading, spacing: 6) {
                Text("GRADE LEVEL")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Picker("Grade", selection: $viewModel.gradeLevel) {
                    ForEach(["6", "7", "8", "9", "10", "11", "12"], id: \.self) { grade in
                        Text("Grade \(grade)").tag(grade)
                    }
                }
                .pickerStyle(.segmented)
            }

            // TEKS Code
            VStack(alignment: .leading, spacing: 6) {
                Text("TEKS STANDARD")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(2)

                HStack {
                    TextField("e.g. M8.4A", text: $viewModel.teksCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                    // Quick lookup
                    if !viewModel.teksCode.isEmpty {
                        if let entry = viewModel.lookupTEKS() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Show matched standard
                if let entry = viewModel.lookupTEKS() {
                    Text(entry.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            // User Intent (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("FOCUS (OPTIONAL)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(2)

                TextField(
                    "e.g. Hands-on activities, real-world examples, ELL focus...",
                    text: $viewModel.userIntent,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Generate Button

struct GenerateButton: View {
    @Bindable var viewModel: LessonPlannerViewModel

    var body: some View {
        Button {
            Task { await viewModel.generate() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(viewModel.isGenerating ? "Generating..." : "Generate Lesson Plan")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.teksCode.isEmpty || viewModel.isGenerating)
        .padding(.vertical, 8)

        // Error display
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.top, 4)
        }
    }
}

// MARK: - Lesson Plan View

struct LessonPlanView: View {
    let plan: TEKSLessonPlan
    let ledger: GenerationLedger<TEKSLessonPlan>?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plan.teksCode.joined(separator: ", "))
                        .font(.caption.monospaced())
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.12))
                        .clipShape(Capsule())

                    Text(plan.bloomLevel.rawValue)
                        .font(.caption.monospaced())
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.purple.opacity(0.12))
                        .clipShape(Capsule())

                    Text("\(plan.durationMinutes) min")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(plan.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Objective
            PlanSection(title: "OBJECTIVE") {
                Text(plan.objective)
                    .font(.body)
            }

            // Materials
            PlanSection(title: "MATERIALS") {
                FlowLayout(spacing: 6) {
                    ForEach(plan.materials, id: \.self) { material in
                        Text(material)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
            }

            // Phases
            PlanSection(title: "LESSON FLOW") {
                ForEach(Array(plan.phases.enumerated()), id: \.offset) { index, phase in
                    PhaseView(phase: phase, index: index)
                }
            }

            // Assessment
            PlanSection(title: "ASSESSMENT") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.assessment.type.uppercased())
                            .font(.caption2.monospaced())
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        if plan.assessment.alignsToObjective {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Aligned")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    Text(plan.assessment.description)
                        .font(.callout)
                }
            }

            // Differentiation
            PlanSection(title: "DIFFERENTIATION") {
                DifferentiationGrid(diff: plan.differentiation)
            }

            // Closure
            PlanSection(title: "CLOSURE") {
                Text(plan.closure)
                    .font(.callout)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Phase View

struct PhaseView: View {
    let phase: LessonPhase
    let index: Int

    let phaseColors: [Color] = [.blue, .purple, .green, .orange]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(phaseColors[index % phaseColors.count])
                    .frame(width: 8, height: 8)
                Text(phase.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(phase.durationMinutes) min")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(phase.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TEACHER")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    ForEach(phase.teacherActions, id: \.self) { action in
                        Text("• \(action)")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("STUDENTS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                    ForEach(phase.studentActions, id: \.self) { action in
                        Text("• \(action)")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Differentiation Grid

struct DifferentiationGrid: View {
    let diff: Differentiation

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            DiffCard(label: "ELL", text: diff.ell, color: .blue)
            DiffCard(label: "SPED", text: diff.specialEducation, color: .purple)
            DiffCard(label: "GT", text: diff.gifted, color: .orange)
            DiffCard(label: "STRUGGLING", text: diff.struggling, color: .green)
        }
    }
}

struct DiffCard: View {
    let label: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Ledger Stats (proof of thesis)

struct LedgerStatsView: View {
    let ledger: GenerationLedger<TEKSLessonPlan>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GENERATION LEDGER")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(2)

            HStack(spacing: 16) {
                StatPill(
                    label: "Attempts",
                    value: "\(ledger.attemptCount)",
                    color: .blue
                )
                if let tokens = ledger.totalTokens {
                    StatPill(
                        label: "Input",
                        value: "\(tokens.input)",
                        color: .purple
                    )
                    StatPill(
                        label: "Output",
                        value: "\(tokens.output)",
                        color: .green
                    )
                    StatPill(
                        label: "Ratio",
                        value: String(format: "%.1f%%", tokens.compressionRatio(windowSize: 4096) * 100),
                        color: tokens.compressionRatio(windowSize: 4096) < 0.4 ? .green : .orange
                    )
                }
                StatPill(
                    label: "Status",
                    value: statusLabel,
                    color: statusColor
                )
            }
        }
        .padding()
        .background(.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.vertical)
    }

    var statusLabel: String {
        switch ledger.status {
        case .valid: return "VALID"
        case .softPass: return "SOFT"
        case .exhausted: return "BEST"
        case .failed: return "FAIL"
        case .pending: return "..."
        }
    }

    var statusColor: Color {
        switch ledger.status {
        case .valid: return .green
        case .softPass: return .yellow
        case .exhausted: return .orange
        case .failed: return .red
        case .pending: return .secondary
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospaced())
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Plan Section

struct PlanSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(2)
            content
        }
    }
}

// MARK: - Flow Layout (for material chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    ContentView()
}
