import Foundation

/// AI-powered Game Master that analyzes conversation in real-time
/// and drives game mechanics independently of the avatar's tool calls.
@MainActor
@Observable
final class GameMasterService {
    var suspicionLevel: Double = 0  // 0.0 to 1.0
    var detectiveInstinct: String?  // Current intuition hint
    var isAnalyzing = false

    private var conversationLog: [(role: String, text: String)] = []
    private var analysisTask: Task<Void, Never>?
    private var lastAnalysisTime: Date = .distantPast
    private let minAnalysisInterval: TimeInterval = 8  // Don't analyze more than every 8s

    // Callback to push events into GameState
    var onGameEvent: ((GameMasterEvent) -> Void)?

    struct GameMasterEvent {
        let cluesDetected: [DetectedClue]
        let contradictionDetected: DetectedContradiction?
        let suggestedQuestion: String?
        let suspicionDelta: Double
        let instinct: String?
    }

    struct DetectedClue {
        let clueId: String
        let text: String
        let importance: String
        let lineId: String?
    }

    struct DetectedContradiction {
        let originalClaim: String
        let newClaim: String
    }

    // MARK: - Feed Transcript

    /// Called every time a new transcription segment arrives from LiveKit
    func feedTranscript(role: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversationLog.append((role, trimmed))

        // Only analyze after suspect speaks (not user)
        guard role == "assistant" || role == "suspect" else { return }

        // Don't queue if already analyzing — let the current request finish
        guard !isAnalyzing else { return }

        // Throttle: don't analyze too frequently
        let timeSinceLastAnalysis = Date().timeIntervalSince(lastAnalysisTime)
        guard timeSinceLastAnalysis >= minAnalysisInterval else { return }

        // Schedule analysis after a short delay to batch rapid transcript segments
        // Don't cancel in-flight requests — only cancel the sleep delay
        analysisTask?.cancel()
        analysisTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await analyze()
        }
    }

    // MARK: - Analyze

    private var scenarioContext: String = ""
    private var suspectContext: String = ""
    private var knownClueIds: Set<String> = []

    func configure(scenario: MysteryScenario, suspect: SuspectDefinition, discoveredClueIds: Set<String>) {
        self.knownClueIds = discoveredClueIds
        self.conversationLog = []
        self.suspicionLevel = 0
        self.detectiveInstinct = nil

        // Build compact scenario context for the LLM
        let clueList = suspect.clues.map { "- \($0.id): \($0.text) [\($0.importance.rawValue), line: \($0.lineId ?? "none")]" }.joined(separator: "\n")
        let allClueIds = suspect.clues.map(\.id).joined(separator: ", ")

        self.suspectContext = """
        SUSPECT: \(suspect.name) (\(suspect.role))
        KNOWN CLUES FOR THIS SUSPECT (IDs: \(allClueIds)):
        \(clueList)
        """

        self.scenarioContext = """
        CASE: \(scenario.title)
        VICTIM: \(scenario.victimName)
        GUILTY: \(scenario.solution.guiltySubjectId)
        TRUTH: \(scenario.solution.explanation)
        \(suspectContext)
        """
    }

    private func analyze() async {
        isAnalyzing = true
        lastAnalysisTime = Date()

        // Build the recent conversation (last 6 exchanges max)
        let recent = conversationLog.suffix(12)
        let transcript = recent.map { "\($0.role == "user" ? "DETECTIVE" : "SUSPECT"): \($0.text)" }.joined(separator: "\n")
        let alreadyFound = knownClueIds.joined(separator: ", ")

        let systemPrompt = """
        You are the Game Master for a murder mystery game. Analyze the interrogation transcript and return a JSON object.

        \(scenarioContext)

        ALREADY DISCOVERED CLUE IDs: \(alreadyFound.isEmpty ? "none" : alreadyFound)

        Analyze the MOST RECENT suspect response and return ONLY a JSON object (no markdown, no explanation):
        {
          "clues_detected": [{"clue_id": "exact_id_from_list", "text": "what was revealed", "importance": "critical|supporting|red_herring", "line_id": "timeline|motive|relationships|evidence"}],
          "contradiction": {"original": "what they said before", "new_claim": "what they just said"} or null,
          "suggested_question": "A natural follow-up question the detective should ask next based on what was just said" or null,
          "suspicion_delta": 0.0 to 0.15 (how much more suspicious this response was - 0 if normal, higher if evasive/nervous),
          "instinct": "A short detective intuition like 'They hesitated when mentioning the kitchen...' or 'Their timeline doesn't add up'" or null
        }

        Rules:
        - Only detect clues that match the KNOWN CLUE IDs list. Do not invent new clues.
        - Only flag clues that were ACTUALLY revealed in the conversation, not ones you wish were revealed.
        - Do not re-detect clues already in ALREADY DISCOVERED.
        - suggested_question should be conversational and natural, referencing what was just said.
        - instinct should be brief, evocative, and help the player know what to focus on.
        - Return ONLY the JSON object, nothing else.
        """

        do {
            let response = try await callOpenAI(system: systemPrompt, user: "RECENT TRANSCRIPT:\n\(transcript)")
            guard let data = response.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                isAnalyzing = false
                return
            }

            // Parse clues
            var clues: [DetectedClue] = []
            if let clueArray = json["clues_detected"] as? [[String: Any]] {
                for c in clueArray {
                    if let id = c["clue_id"] as? String,
                       let text = c["text"] as? String,
                       !knownClueIds.contains(id) {
                        let importance = c["importance"] as? String ?? "supporting"
                        let lineId = c["line_id"] as? String
                        clues.append(DetectedClue(clueId: id, text: text, importance: importance, lineId: lineId))
                        knownClueIds.insert(id)
                    }
                }
            }

            // Parse contradiction
            var contradiction: DetectedContradiction?
            if let c = json["contradiction"] as? [String: Any],
               let original = c["original"] as? String,
               let newClaim = c["new_claim"] as? String {
                contradiction = DetectedContradiction(originalClaim: original, newClaim: newClaim)
            }

            // Parse suggestion
            let suggestion = json["suggested_question"] as? String

            // Parse suspicion
            let suspicionDelta = json["suspicion_delta"] as? Double ?? 0

            // Parse instinct
            let instinct = json["instinct"] as? String

            // Update suspicion level
            suspicionLevel = min(1.0, suspicionLevel + suspicionDelta)
            if let instinct { detectiveInstinct = instinct }

            // Fire event if anything interesting happened
            if !clues.isEmpty || contradiction != nil || suggestion != nil || instinct != nil {
                let event = GameMasterEvent(
                    cluesDetected: clues,
                    contradictionDetected: contradiction,
                    suggestedQuestion: suggestion,
                    suspicionDelta: suspicionDelta,
                    instinct: instinct
                )
                onGameEvent?(event)
            }
        } catch {
            print("[GameMaster] Analysis failed: \(error)")
        }

        isAnalyzing = false
    }

    // MARK: - OpenAI API Call

    private func callOpenAI(system: String, user: String) async throws -> String {
        let url = URL(string: "\(Config.backendURL)/api/openai/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appAuthToken, forHTTPHeaderField: "X-App-Token")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.3,
            "max_tokens": 500,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw URLError(.badServerResponse)
        }

        // Strip markdown code fences if present
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Reset

    func reset() {
        analysisTask?.cancel()
        conversationLog = []
        suspicionLevel = 0
        detectiveInstinct = nil
        knownClueIds = []
        isAnalyzing = false
    }
}
