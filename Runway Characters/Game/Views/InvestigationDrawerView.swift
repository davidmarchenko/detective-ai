import SwiftUI

struct InvestigationDrawerView: View {
    @Bindable var gameState: GameState
    let suspectId: String
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    @State private var selectedActionId: String?
    @State private var selectedClueForPresent: DiscoveredClue?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    tabButton("Lines", icon: "chart.bar.fill", tag: 0)
                    tabButton("Questions", icon: "questionmark.bubble.fill", tag: 1)
                    tabButton("Actions", icon: "shield.lefthalf.filled", tag: 2)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                // Content
                ScrollView {
                    Group {
                        switch selectedTab {
                        case 0: linesTab
                        case 1: questionsTab
                        case 2: actionsTab
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Investigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(DT.Colors.warmGlow)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(DT.Colors.void)
        .preferredColorScheme(.dark)
    }

    // MARK: - Tab Button

    private func tabButton(_ label: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tag }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selectedTab == tag ? .orange : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == tag ? .orange.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Lines Tab

    private var linesTab: some View {
        VStack(spacing: 10) {
            ForEach(gameState.mystery?.investigationLines ?? []) { line in
                let progress = gameState.lineProgress(for: suspectId, lineId: line.id)
                HStack(spacing: 12) {
                    Image(systemName: line.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(progress > 0 ? .orange : .white.opacity(0.3))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(line.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(progress >= line.maxDepth ? .green : .orange)
                                    .frame(width: geo.size.width * CGFloat(min(progress, line.maxDepth)) / CGFloat(line.maxDepth))
                                    .animation(.easeOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 4)
                    }

                    Text("\(min(progress, line.maxDepth))/\(line.maxDepth)")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(progress >= line.maxDepth ? .green : .orange)
                }
                .padding(10)
                .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Questions Tab

    private var questionsTab: some View {
        let available = gameState.availableQuestions(for: suspectId)
        let allQuestions = gameState.suspect(for: suspectId)?.suggestedQuestions ?? []
        let locked = allQuestions.filter { q in !available.contains(where: { $0.id == q.id }) }

        return VStack(spacing: 8) {
            if available.isEmpty && locked.isEmpty {
                Text("No suggested questions for this suspect")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 20)
            }

            // Available questions
            ForEach(available) { question in
                let used = gameState.usedQuestionIds.contains(question.id)
                Button {
                    gameState.usedQuestionIds.insert(question.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: used ? "checkmark.circle.fill" : "quote.opening")
                            .font(.system(size: 14))
                            .foregroundStyle(used ? .green : .orange)
                            .frame(width: 20)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(question.text)
                                .font(.system(size: 14))
                                .foregroundStyle(used ? .white.opacity(0.4) : .white)
                                .multilineTextAlignment(.leading)
                            lineLabel(question.lineId)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(used ? .white.opacity(0.02) : .orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(used ? .clear : .orange.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Locked questions
            ForEach(locked) { question in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.2))
                        .frame(width: 20)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discover more clues to unlock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                        lineLabel(question.lineId)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func lineLabel(_ lineId: String) -> some View {
        let line = gameState.mystery?.investigationLines?.first { $0.id == lineId }
        return HStack(spacing: 4) {
            if let line {
                Image(systemName: line.icon)
                    .font(.system(size: 9))
                Text(line.label)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundStyle(.white.opacity(0.3))
    }

    // MARK: - Actions Tab

    private var actionsTab: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(gameState.mystery?.detectiveActions ?? []) { action in
                let available = gameState.isActionAvailable(action)
                let isSelected = selectedActionId == action.id

                Button {
                    if available {
                        withAnimation {
                            selectedActionId = isSelected ? nil : action.id
                            if action.id == "present_evidence" && !isSelected {
                                selectedClueForPresent = nil
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(available ? .orange : .white.opacity(0.2))
                        Text(action.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(available ? .white : .white.opacity(0.2))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isSelected ? .orange.opacity(0.15) : .white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? .orange.opacity(0.5) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!available)
            }

            // Coaching hint (full width below grid)
            if let actionId = selectedActionId,
               let action = gameState.mystery?.detectiveActions?.first(where: { $0.id == actionId }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAY THIS:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(2)

                    if action.id == "present_evidence" {
                        // Show clue picker
                        if let selected = selectedClueForPresent {
                            Text("\"I have evidence that \(selected.text). How do you explain that?\"")
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(.white)
                                .italic()
                        } else {
                            Text("Pick a clue to present:")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                            ForEach(gameState.discoveredClues) { clue in
                                Button {
                                    selectedClueForPresent = clue
                                } label: {
                                    Text(clue.text)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if action.id == "catch_contradiction" && !gameState.contradictions.isEmpty {
                        let c = gameState.contradictions.last!
                        Text("\"You said '\(c.original)', but now you're saying '\(c.corrected)'. Which is it?\"")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(.white)
                            .italic()
                    } else {
                        Text(action.promptHint)
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(.white)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .gridCellColumns(2)
            }
        }
    }
}
