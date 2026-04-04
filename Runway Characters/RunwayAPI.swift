import Foundation

// MARK: - API Types

struct CreateSessionRequest: Encodable {
    let model: String
    let avatar: AvatarConfig
    let personality: String?
    let startScript: String?
    let tools: [ToolDefinition]?
}

struct AvatarConfig: Encodable {
    let type: String
    let presetId: String?
    let avatarId: String?

    static func preset(_ id: String) -> AvatarConfig {
        AvatarConfig(type: "runway-preset", presetId: id, avatarId: nil)
    }

    static func custom(_ id: String) -> AvatarConfig {
        AvatarConfig(type: "custom", presetId: nil, avatarId: id)
    }
}

struct ToolDefinition: Encodable {
    let type: String
    let name: String
    let description: String
    let parameters: [[String: String]]?
    let timeoutSeconds: Int?
}

struct CreateSessionResponse: Decodable {
    let id: String
}

struct SessionStatusResponse: Decodable {
    let status: String
    let sessionKey: String?
}

struct ConsumeSessionResponse: Decodable {
    let url: String
    let token: String
    let roomName: String
}

// MARK: - API Errors

enum RunwayAPIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, body: String)
    case sessionTimeout
    case sessionFailed(status: String)
    case missingSessionKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        case .sessionTimeout: "Session did not become ready within timeout"
        case .sessionFailed(let status): "Session entered terminal state: \(status)"
        case .missingSessionKey: "Session is READY but no sessionKey was returned"
        }
    }
}

// MARK: - API Client (calls backend proxy — no API keys on device)

actor RunwayAPI {
    private let backendURL: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(backendURL: String = Config.backendURL) {
        self.backendURL = backendURL
        self.session = URLSession.shared
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Create Session

    func createSession(
        avatar: AvatarConfig,
        personality: String? = nil,
        startScript: String? = nil,
        tools: [ToolDefinition]? = nil
    ) async throws -> String {
        let body = CreateSessionRequest(
            model: Config.runwayModel,
            avatar: avatar,
            personality: personality,
            startScript: startScript,
            tools: tools
        )
        let response: CreateSessionResponse = try await post(
            path: "/api/session/create",
            body: body
        )
        return response.id
    }

    // MARK: - Poll Until Ready

    func waitForSession(
        id: String,
        pollInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 120.0
    ) async throws -> String {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let status = try await getSessionStatus(id: id)

            switch status.status {
            case "READY", "RUNNING":
                guard let sessionKey = status.sessionKey else {
                    throw RunwayAPIError.missingSessionKey
                }
                return sessionKey
            case "COMPLETED", "FAILED", "CANCELLED":
                throw RunwayAPIError.sessionFailed(status: status.status)
            default:
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }

        throw RunwayAPIError.sessionTimeout
    }

    // MARK: - Get Session Status

    func getSessionStatus(id: String) async throws -> SessionStatusResponse {
        try await get(path: "/api/session/\(id)/status")
    }

    // MARK: - Consume Session (get LiveKit credentials)

    func consumeSession(id: String, sessionKey: String) async throws -> ConsumeSessionResponse {
        try await post(
            path: "/api/session/\(id)/consume",
            body: Optional<String>.none,
            extraHeaders: ["X-Session-Key": sessionKey]
        )
    }

    // MARK: - HTTP Helpers

    private func get<R: Decodable>(path: String) async throws -> R {
        guard let url = URL(string: backendURL + path) else {
            throw RunwayAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Config.appAuthToken, forHTTPHeaderField: "X-App-Token")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(R.self, from: data)
    }

    private func post<B: Encodable, R: Decodable>(
        path: String,
        body: B?,
        extraHeaders: [String: String] = [:]
    ) async throws -> R {
        guard let url = URL(string: backendURL + path) else {
            throw RunwayAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appAuthToken, forHTTPHeaderField: "X-App-Token")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(R.self, from: data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw RunwayAPIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}
