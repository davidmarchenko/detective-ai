import Foundation

// MARK: - Mystery Scenario

struct MysteryScenario: Codable, Identifiable {
    let id: String
    let title: String
    let briefing: String
    let victimName: String
    let setting: String
    let suspects: [SuspectDefinition]
    let solution: Solution
    let quickPlaySuspectId: String
    let investigationLines: [InvestigationLine]?
    let detectiveActions: [DetectiveAction]?
}

// MARK: - Suspect

struct SuspectDefinition: Codable, Identifiable {
    let id: String
    let name: String
    let role: String
    let presetId: String?       // Runway preset avatar (use one or the other)
    let avatarId: String?       // Runway custom avatar
    let briefDescription: String
    let personality: String     // Full prompt injected at session creation
    let startScript: String?    // Opening line when call connects
    let clues: [ClueDefinition]
    let suggestedQuestions: [SuggestedQuestion]?

    var avatarConfig: AvatarConfig {
        if let avatarId {
            .custom(avatarId)
        } else if let presetId {
            .preset(presetId)
        } else {
            fatalError("Suspect must have either presetId or avatarId")
        }
    }
}

// MARK: - Clue

struct ClueDefinition: Codable, Identifiable {
    let id: String
    let text: String
    let importance: ClueImportance
    let lineId: String?  // Maps to an InvestigationLine
}

enum ClueImportance: String, Codable {
    case critical
    case supporting
    case redHerring = "red_herring"
}

// MARK: - Investigation Line

struct InvestigationLine: Codable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let description: String
    let maxDepth: Int
}

// MARK: - Suggested Question

struct SuggestedQuestion: Codable, Identifiable {
    let id: String
    let text: String
    let lineId: String
    let depth: Int
    let unlocksAfterClues: [String]  // Clue IDs that must be discovered first
}

// MARK: - Detective Action

struct DetectiveAction: Codable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let description: String
    let promptHint: String
    let requiresClueCount: Int?
    let requiresContradictionCount: Int?
    let requiresEmotionalShift: Bool?
}

// MARK: - Solution

struct Solution: Codable {
    let guiltySubjectId: String
    let motive: String
    let explanation: String
}

// MARK: - Discovered Clue (runtime)

struct DiscoveredClue: Identifiable, Equatable {
    let id = UUID()
    let clueId: String
    let text: String
    let importance: String
    let lineId: String?
    let suspectId: String
    let timestamp: Date
}

// MARK: - Game Phase

enum GamePhase: Equatable {
    case lobby
    case briefing
    case suspectBoard
    case interrogation(suspectId: String)
    case evidence
    case accusation
    case verdict
}

// MARK: - Game Mode

enum GameMode: String, Codable {
    case quickPlay      // 5 min, 1 suspect
    case standardPlay   // 15-30 min, all suspects
}

// MARK: - Game Score

struct GameScore {
    let cluesFound: Int
    let totalClues: Int
    let contradictionsCaught: Int
    let correctAccusation: Bool
    let correctMotive: Bool
    let timeTaken: TimeInterval

    var totalPoints: Int {
        var points = 0
        points += cluesFound * 10
        points += contradictionsCaught * 25
        points += correctAccusation ? 100 : 0
        points += correctMotive ? 50 : 0
        // Time bonus for quick solve
        if correctAccusation && timeTaken < 180 {
            points += 50
        }
        return points
    }

    var rating: String {
        switch totalPoints {
        case 200...: "Master Detective"
        case 150..<200: "Senior Inspector"
        case 100..<150: "Detective"
        case 50..<100: "Rookie"
        default: "Suspect Got Away"
        }
    }
}

// MARK: - Scenario Loader

enum MysteryLoader {
    static func loadAll() -> [MysteryScenario] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            return []
        }
        return urls.compactMap { url -> MysteryScenario? in
            guard url.lastPathComponent.hasPrefix("mystery_") else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(MysteryScenario.self, from: data)
        }
    }

    static func load(named name: String) -> MysteryScenario? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MysteryScenario.self, from: data)
    }
}
