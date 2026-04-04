import Foundation

enum GameTools {
    static let interrogationTools: [ToolDefinition] = [
        ToolDefinition(
            type: "client_event",
            name: "reveal_clue",
            description: "Call this whenever you share an important piece of evidence or information about the case with the detective. This includes facts about the crime, timeline details, observations, or anything that could help or mislead the investigation.",
            parameters: [
                ["name": "clue_id", "type": "string", "description": "A short snake_case identifier for this clue"],
                ["name": "clue_text", "type": "string", "description": "A concise summary of the key fact or evidence revealed"],
                ["name": "importance", "type": "string", "description": "One of: critical, supporting, or red_herring"]
            ],
            timeoutSeconds: nil
        ),
        ToolDefinition(
            type: "client_event",
            name: "suspicion_shift",
            description: "Call this when you point blame or suspicion at another person involved in the case.",
            parameters: [
                ["name": "target_suspect", "type": "string", "description": "Name of the person you are blaming or casting suspicion on"],
                ["name": "reason", "type": "string", "description": "Brief reason why you suspect them"]
            ],
            timeoutSeconds: nil
        ),
        ToolDefinition(
            type: "client_event",
            name: "emotional_shift",
            description: "Call this when your emotional state changes significantly during the interrogation. For example, becoming nervous when a sensitive topic comes up, getting angry when accused, or breaking down under pressure.",
            parameters: [
                ["name": "emotion", "type": "string", "description": "One of: nervous, angry, defensive, sad, panicked, relieved, defiant, calm"],
                ["name": "trigger", "type": "string", "description": "What the detective said or asked that caused this emotional change"]
            ],
            timeoutSeconds: nil
        ),
        ToolDefinition(
            type: "client_event",
            name: "contradiction",
            description: "Call this if the detective catches you in a contradiction or inconsistency in your story and you must adjust or explain the discrepancy.",
            parameters: [
                ["name": "original_claim", "type": "string", "description": "What you originally stated"],
                ["name": "corrected_claim", "type": "string", "description": "Your revised or corrected statement"]
            ],
            timeoutSeconds: nil
        ),
        ToolDefinition(
            type: "client_event",
            name: "interrogation_milestone",
            description: "Call this when a significant moment occurs in the interrogation: the detective asks their first truly probing question, when you reveal something important for the first time, when the interrogation reaches a turning point, or if you are near confessing or actually confessing.",
            parameters: [
                ["name": "milestone", "type": "string", "description": "One of: first_probe, key_reveal, turning_point, near_confession, confession"]
            ],
            timeoutSeconds: nil
        )
    ]

    /// Parse a client_event data channel message into tool name and args
    static func parseEvent(_ json: [String: Any]) -> (tool: String, args: [String: Any])? {
        guard let type = json["type"] as? String, type == "client_event",
              let tool = json["tool"] as? String,
              let args = json["args"] as? [String: Any] else {
            return nil
        }
        // Filter out ack messages
        if let status = args["status"] as? String, status == "event_sent" {
            return nil
        }
        return (tool, args)
    }
}
