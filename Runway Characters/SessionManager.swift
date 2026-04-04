import Foundation
import Combine
import AVFoundation
import LiveKit

// MARK: - Session State

enum SessionState: Equatable {
    case idle
    case connecting
    case active
    case ending
    case ended
    case error(String)

    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting),
             (.active, .active), (.ending, .ending), (.ended, .ended):
            true
        case (.error(let a), .error(let b)):
            a == b
        default:
            false
        }
    }
}

// MARK: - Transcription Entry

struct TranscriptionEntry: Identifiable, Equatable {
    let id = UUID()
    let role: String  // "user" or "assistant"
    let text: String
    let timestamp: Date
}

// MARK: - Session Manager

@MainActor
@Observable
final class SessionManager {
    // Public state
    var state: SessionState = .idle
    var connectingStatus: String = ""
    var transcriptions: [TranscriptionEntry] = []
    var remoteVideoTrack: VideoTrack?
    var remoteAudioTrack: AudioTrack?
    var isCameraOn = true

    // Game event callback
    var onGameEvent: ((String, [String: Any]) -> Void)?

    // Private
    private let api = RunwayAPI()
    private(set) var _room: Room?
    private var sessionId: String?
    private var roomDelegate: RoomDelegateHandler?

    // MARK: - Connect

    func connect(avatar: AvatarConfig, personality: String? = nil, startScript: String? = nil, tools: [ToolDefinition]? = nil) async {
        guard state == .idle || state == .ended || state.isError else { return }

        state = .connecting
        transcriptions = []
        remoteVideoTrack = nil
        remoteAudioTrack = nil

        do {
            // 0. Request mic & camera permissions upfront (before creating a billable session)
            let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
            let camGranted = await AVCaptureDevice.requestAccess(for: .video)
            guard micGranted else {
                state = .error("Microphone permission is required for calls.")
                return
            }
            guard camGranted else {
                state = .error("Camera permission is required for calls.")
                return
            }

            // 1. Create session
            connectingStatus = "Creating session..."
            let sessionId = try await api.createSession(
                avatar: avatar,
                personality: personality,
                startScript: startScript,
                tools: tools
            )
            self.sessionId = sessionId

            // 2. Poll until ready
            connectingStatus = "Waiting for avatar..."
            let sessionKey = try await api.waitForSession(id: sessionId)

            // 3. Consume to get LiveKit credentials
            connectingStatus = "Getting connection..."
            let credentials = try await api.consumeSession(
                id: sessionId,
                sessionKey: sessionKey
            )

            // 4. Connect to LiveKit room
            connectingStatus = "Connecting..."
            let room = Room()
            self._room = room

            let delegate = RoomDelegateHandler(manager: self)
            self.roomDelegate = delegate
            room.add(delegate: delegate)

            try await room.connect(url: credentials.url, token: credentials.token)

            // 5. Enable microphone and camera
            connectingStatus = "Starting media..."
            try await room.localParticipant.setMicrophone(enabled: true)
            try await room.localParticipant.setCamera(enabled: true)

            connectingStatus = ""
            state = .active
        } catch {
            if state != .ending && state != .ended {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        guard state == .active || state == .connecting else { return }
        state = .ending

        // Send end_call signal via data channel
        if let room = _room, room.connectionState == .connected {
            let endMessage = try? JSONSerialization.data(
                withJSONObject: ["type": "end_call"]
            )
            if let endMessage {
                try? await room.localParticipant.publish(
                    data: endMessage,
                    options: DataPublishOptions(reliable: true)
                )
            }
        }

        await _room?.disconnect()
        cleanup()
        state = .ended
    }

    // MARK: - Cleanup

    private func cleanup() {
        _room = nil
        roomDelegate = nil
        sessionId = nil
        remoteVideoTrack = nil
        remoteAudioTrack = nil
    }

    // MARK: - Handle incoming data messages

    fileprivate func handleDataReceived(_ data: Data, participant: RemoteParticipant?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Handle transcription messages
        if let type = json["type"] as? String, type == "transcription",
           let role = json["role"] as? String,
           let text = json["text"] as? String {
            let entry = TranscriptionEntry(role: role, text: text, timestamp: Date())
            transcriptions.append(entry)
        }

        // Handle client_event messages → forward to game layer
        if let type = json["type"] as? String, type == "client_event",
           let tool = json["tool"] as? String,
           let args = json["args"] as? [String: Any] {
            // Filter ack messages
            if let status = args["status"] as? String, status == "event_sent" { return }
            onGameEvent?(tool, args)
        }
    }

    fileprivate func handleTrackSubscribed(track: Track, participant: RemoteParticipant) {
        switch track.kind {
        case .video:
            remoteVideoTrack = track as? VideoTrack
        case .audio:
            remoteAudioTrack = track as? AudioTrack
        default:
            break
        }
    }

    fileprivate func handleTrackUnsubscribed(track: Track, participant: RemoteParticipant) {
        switch track.kind {
        case .video:
            if remoteVideoTrack?.sid == track.sid {
                remoteVideoTrack = nil
            }
        case .audio:
            if remoteAudioTrack?.sid == track.sid {
                remoteAudioTrack = nil
            }
        default:
            break
        }
    }

    fileprivate func handleDisconnected() {
        if state != .ending && state != .ended {
            // Brief grace period — check if LiveKit reconnects
            state = .error("Connection lost. Attempting to reconnect...")
            Task {
                try? await Task.sleep(for: .seconds(5))
                // If still not reconnected after 5s, end the session
                if let room = _room, room.connectionState == .connected {
                    state = .active  // Reconnected!
                } else if state != .ending && state != .ended {
                    state = .ended
                    cleanup()
                }
            }
        } else {
            cleanup()
        }
    }
}

// MARK: - SessionState helpers

extension SessionState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Room Delegate

@MainActor
private final class RoomDelegateHandler: RoomDelegate {
    weak var manager: SessionManager?

    init(manager: SessionManager) {
        self.manager = manager
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        guard let track = publication.track else { return }
        Task { @MainActor in
            manager?.handleTrackSubscribed(track: track, participant: participant)
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        guard let track = publication.track else { return }
        Task { @MainActor in
            manager?.handleTrackUnsubscribed(track: track, participant: participant)
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        Task { @MainActor in
            manager?.handleDataReceived(data, participant: participant)
        }
    }

    nonisolated func room(_ room: Room, didDisconnectWithError error: (any Error)?) {
        // Only handle as final disconnect if there was an actual error
        // LiveKit may call this during reconnection attempts
        if error != nil {
            Task { @MainActor in
                manager?.handleDisconnected()
            }
        }
    }
}
