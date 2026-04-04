import Foundation

@MainActor
@Observable
final class GameState {
    // Current game
    var mystery: MysteryScenario?
    var mode: GameMode = .quickPlay
    var phase: GamePhase = .lobby

    // Evidence collected across all interrogations
    var discoveredClues: [DiscoveredClue] = []
    var contradictions: [(original: String, corrected: String, suspectId: String)] = []
    var suspicionShifts: [(from: String, target: String, reason: String)] = []

    // Per-suspect status
    var interviewedSuspects: Set<String> = []
    var currentSuspectId: String?

    // Timing
    var gameStartTime: Date?
    var callStartTime: Date?

    // Result
    var accusedSuspectId: String?
    var selectedMotive: String?
    var score: GameScore?

    // Game Master (AI-powered conversation analysis)
    let gameMaster = GameMasterService()

    // Investigation tracking
    var usedQuestionIds: Set<String> = []
    var lineProgress: [String: Int] = [:]  // key: "suspectId_lineId"
    var currentEmotionalShiftOccurred = false
    var newQuestionsAvailable = false  // pulse flag for the Investigate button

    // MARK: - Start Game

    func startGame(mystery: MysteryScenario, mode: GameMode) {
        self.mystery = mystery
        self.mode = mode
        self.phase = .briefing
        self.discoveredClues = []
        self.contradictions = []
        self.suspicionShifts = []
        self.interviewedSuspects = []
        self.currentSuspectId = nil
        self.gameStartTime = Date()
        self.accusedSuspectId = nil
        self.selectedMotive = nil
        self.score = nil
        self.usedQuestionIds = []
        self.lineProgress = [:]
        self.currentEmotionalShiftOccurred = false
        self.newQuestionsAvailable = false

    }

    // MARK: - Navigation

    func proceedFromBriefing() {
        guard let mystery else { return }
        if mode == .quickPlay {
            // Go straight to interrogating the quick-play suspect
            startInterrogation(suspectId: mystery.quickPlaySuspectId)
        } else {
            phase = .suspectBoard
        }
    }

    func startInterrogation(suspectId: String) {
        currentSuspectId = suspectId
        callStartTime = Date()
        currentEmotionalShiftOccurred = false
        phase = .interrogation(suspectId: suspectId)
    }

    func endInterrogation() {
        if let currentSuspectId {
            interviewedSuspects.insert(currentSuspectId)
        }
        currentSuspectId = nil
        callStartTime = nil

        if mode == .quickPlay {
            phase = .accusation
        } else {
            // Check if all suspects interviewed
            let allInterviewed = mystery?.suspects.allSatisfy {
                interviewedSuspects.contains($0.id)
            } ?? false
            phase = allInterviewed ? .accusation : .evidence
        }
    }

    func returnToSuspectBoard() {
        phase = .suspectBoard
    }

    func goToAccusation() {
        phase = .accusation
    }

    func submitAccusation(suspectId: String, motive: String?) {
        guard let mystery else { return }
        accusedSuspectId = suspectId
        selectedMotive = motive

        let totalClues = mystery.suspects.flatMap(\.clues).count
        let timeTaken = gameStartTime.map { Date().timeIntervalSince($0) } ?? 0

        score = GameScore(
            cluesFound: discoveredClues.count,
            totalClues: totalClues,
            contradictionsCaught: contradictions.count,
            correctAccusation: suspectId == mystery.solution.guiltySubjectId,
            correctMotive: motive != nil && mystery.solution.motive.localizedCaseInsensitiveContains(motive!),
            timeTaken: timeTaken
        )
        phase = .verdict
    }

    func resetToLobby() {
        mystery = nil
        phase = .lobby
    }

    func returnToBriefing() {
        phase = .briefing
    }

    func returnToEvidence() {
        phase = .evidence
    }

    func replayCurrentCase() {
        guard let mystery else { return }
        startGame(mystery: mystery, mode: mode)
    }

    // MARK: - Game Event Handler (called from SessionManager)

    func handleGameEvent(tool: String, args: [String: Any]) {
        guard let currentSuspectId else { return }

        switch tool {
        case "reveal_clue":
            if let clueId = args["clue_id"] as? String,
               let text = args["clue_text"] as? String {
                let importance = args["importance"] as? String ?? "supporting"
                // Look up the lineId from the scenario's clue definition
                let clueDef = currentSuspect?.clues.first { $0.id == clueId }
                let lineId = clueDef?.lineId

                let clue = DiscoveredClue(
                    clueId: clueId,
                    text: text,
                    importance: importance,
                    lineId: lineId,
                    suspectId: currentSuspectId,
                    timestamp: Date()
                )
                let prevCount = availableQuestions(for: currentSuspectId).count
                if !discoveredClues.contains(where: { $0.clueId == clueId }) {
                    discoveredClues.append(clue)
                    // Update line progress
                    if let lineId {
                        let key = "\(currentSuspectId)_\(lineId)"
                        lineProgress[key, default: 0] += 1
                    }
                    // Check if new questions unlocked
                    let newCount = availableQuestions(for: currentSuspectId).count
                    if newCount > prevCount {
                        newQuestionsAvailable = true
                    }
                }
            }

        case "contradiction":
            if let original = args["original_claim"] as? String,
               let corrected = args["corrected_claim"] as? String {
                contradictions.append((original, corrected, currentSuspectId))
            }

        case "suspicion_shift":
            if let target = args["target_suspect"] as? String,
               let reason = args["reason"] as? String {
                suspicionShifts.append((currentSuspectId, target, reason))
            }

        case "emotional_shift":
            currentEmotionalShiftOccurred = true

        case "interrogation_milestone":
            break

        default:
            break
        }
    }

    // MARK: - Helpers

    func suspect(for id: String) -> SuspectDefinition? {
        mystery?.suspects.first { $0.id == id }
    }

    var currentSuspect: SuspectDefinition? {
        currentSuspectId.flatMap { suspect(for: $0) }
    }

    var suspectsAvailable: [SuspectDefinition] {
        mystery?.suspects ?? []
    }

    // MARK: - Game Master Event Handler

    func handleGameMasterEvent(_ event: GameMasterService.GameMasterEvent) {
        guard let currentSuspectId else { return }

        // Process detected clues
        for clue in event.cluesDetected {
            let prevCount = availableQuestions(for: currentSuspectId).count
            if !discoveredClues.contains(where: { $0.clueId == clue.clueId }) {
                discoveredClues.append(DiscoveredClue(
                    clueId: clue.clueId,
                    text: clue.text,
                    importance: clue.importance,
                    lineId: clue.lineId,
                    suspectId: currentSuspectId,
                    timestamp: Date()
                ))
                if let lineId = clue.lineId {
                    lineProgress["\(currentSuspectId)_\(lineId)", default: 0] += 1
                }
                let newCount = availableQuestions(for: currentSuspectId).count
                if newCount > prevCount { newQuestionsAvailable = true }
            }
        }

        // Process contradiction
        if let c = event.contradictionDetected {
            contradictions.append((c.originalClaim, c.newClaim, currentSuspectId))
        }

        // Update detective instinct
        if let instinct = event.instinct {
            gameMaster.detectiveInstinct = instinct
        }
    }

    // MARK: - Investigation Helpers

    func lineProgress(for suspectId: String, lineId: String) -> Int {
        lineProgress["\(suspectId)_\(lineId)"] ?? 0
    }

    /// Questions available for a suspect (unlocked and not yet used)
    func availableQuestions(for suspectId: String) -> [SuggestedQuestion] {
        guard let suspect = suspect(for: suspectId) else { return [] }
        let discoveredIds = Set(discoveredClues.map(\.clueId))
        return (suspect.suggestedQuestions ?? []).filter { q in
            q.unlocksAfterClues.allSatisfy { discoveredIds.contains($0) }
        }
    }

    /// Whether a specific detective action is currently available
    func isActionAvailable(_ action: DetectiveAction) -> Bool {
        if let req = action.requiresClueCount, discoveredClues.count < req { return false }
        if let req = action.requiresContradictionCount, contradictions.count < req { return false }
        if let req = action.requiresEmotionalShift, req && !currentEmotionalShiftOccurred { return false }
        return true
    }
}
