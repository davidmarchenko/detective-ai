import AVFoundation
import CryptoKit
import Foundation

// MARK: - Alignment Data

struct NarrationAlignment {
    struct WordTiming: Codable {
        let word: String
        let startTime: TimeInterval
        let endTime: TimeInterval
    }
}

// MARK: - Cached Narration

private struct CachedNarration: Codable {
    let audioData: Data
    let wordTimings: [NarrationAlignment.WordTiming]
}

// MARK: - Narration Service

@MainActor
@Observable
final class NarrationService {
    var isPlaying = false
    var isLoading = false
    var currentWordIndex: Int = -1
    var wordTimings: [NarrationAlignment.WordTiming] = []

    private var audioPlayer: AVAudioPlayer?
    private var syncTimer: Timer?

    private static var cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NarrationCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Speak

    func speak(_ text: String) async {
        stop()
        isPlaying = true
        isLoading = true
        currentWordIndex = -1
        wordTimings = []

        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            let cacheKey = Self.cacheKey(for: text)
            let audio: Data
            let timings: [NarrationAlignment.WordTiming]

            // Check cache
            if let cached = Self.loadFromCache(key: cacheKey) {
                print("[NarrationService] Cache hit (\(cached.audioData.count) bytes)")
                audio = cached.audioData
                timings = cached.wordTimings
            } else {
                // Fetch full audio (showing loading state)
                let (fetchedAudio, fetchedTimings) = try await fetchTTSWithTimestamps(text: text)
                audio = fetchedAudio
                timings = fetchedTimings
                print("[NarrationService] Fetched \(audio.count) bytes, \(timings.count) words — caching")
                Self.saveToCache(key: cacheKey, audio: audio, timings: timings)
            }

            guard isPlaying else { return }

            wordTimings = timings
            isLoading = false

            guard !audio.isEmpty else {
                print("[NarrationService] No audio data received")
                isPlaying = false
                return
            }

            // Play from memory
            let player = try AVAudioPlayer(data: audio)
            self.audioPlayer = player
            player.prepareToPlay()
            player.play()
            print("[NarrationService] Playing \(player.duration)s of audio")
            startCaptionSync()

        } catch {
            print("[NarrationService] Error: \(error)")
            isPlaying = false
            isLoading = false
        }
    }

    // MARK: - Stop

    func stop() {
        isPlaying = false
        isLoading = false
        audioPlayer?.stop()
        audioPlayer = nil
        syncTimer?.invalidate()
        syncTimer = nil
        currentWordIndex = -1
    }

    // MARK: - Caption Sync

    private func startCaptionSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCaption()
            }
        }
    }

    private func updateCaption() {
        guard let audioPlayer, isPlaying else { return }

        guard audioPlayer.isPlaying else {
            // Playback finished
            isPlaying = false
            currentWordIndex = wordTimings.count - 1
            syncTimer?.invalidate()
            syncTimer = nil
            return
        }

        let currentTime = audioPlayer.currentTime

        var newIndex = -1
        for (i, timing) in wordTimings.enumerated() {
            if currentTime >= timing.startTime {
                newIndex = i
            } else {
                break
            }
        }

        if newIndex != currentWordIndex {
            currentWordIndex = newIndex
        }
    }

    // MARK: - ElevenLabs API

    private func fetchTTSWithTimestamps(text: String) async throws -> (Data, [NarrationAlignment.WordTiming]) {
        let urlString = "\(Config.backendURL)/api/tts/speak"

        guard let url = URL(string: urlString) else {
            throw NarrationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appAuthToken, forHTTPHeaderField: "X-App-Token")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.6,
                "similarity_boost": 0.75,
                "style": 0.1,
                "speed": 1.0
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NarrationError.httpError(statusCode)
        }

        var audioChunks = Data()
        var allTimings: [NarrationAlignment.WordTiming] = []
        var chunkCount = 0

        // Use .lines which properly handles UTF-8 line buffering
        for try await line in bytes.lines {
            guard isPlaying else { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let jsonData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                print("[NarrationService] Skipped unparseable chunk (\(trimmed.prefix(80))...)")
                continue
            }

            chunkCount += 1

            if let audioB64 = json["audio_base64"] as? String,
               let audioChunk = Data(base64Encoded: audioB64) {
                audioChunks.append(audioChunk)
            }

            if let alignment = json["alignment"] as? [String: Any],
               let chars = alignment["characters"] as? [String],
               let starts = alignment["character_start_times_seconds"] as? [Double],
               let ends = alignment["character_end_times_seconds"] as? [Double] {
                allTimings.append(contentsOf: Self.buildWordTimings(characters: chars, starts: starts, ends: ends))
            }
        }

        print("[NarrationService] Parsed \(chunkCount) chunks, \(audioChunks.count) audio bytes, \(allTimings.count) words")
        return (audioChunks, allTimings)
    }

    // MARK: - Word Timing Builder

    private static func buildWordTimings(
        characters: [String],
        starts: [Double],
        ends: [Double]
    ) -> [NarrationAlignment.WordTiming] {
        var timings: [NarrationAlignment.WordTiming] = []
        var currentWord = ""
        var wordStart: Double?

        for i in 0..<characters.count {
            let char = characters[i]
            if char == " " || char == "\n" {
                if !currentWord.isEmpty, let start = wordStart {
                    timings.append(.init(word: currentWord, startTime: start, endTime: ends[i - 1]))
                }
                currentWord = ""
                wordStart = nil
            } else {
                if wordStart == nil { wordStart = starts[i] }
                currentWord += char
            }
        }
        if !currentWord.isEmpty, let start = wordStart {
            timings.append(.init(word: currentWord, startTime: start, endTime: ends[characters.count - 1]))
        }
        return timings
    }

    // MARK: - Disk Cache

    private static func cacheKey(for text: String) -> String {
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func cacheURL(key: String) -> URL {
        cacheDir.appendingPathComponent("\(key).narration")
    }

    private static func loadFromCache(key: String) -> CachedNarration? {
        let url = cacheURL(key: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedNarration.self, from: data)
    }

    private static func saveToCache(key: String, audio: Data, timings: [NarrationAlignment.WordTiming]) {
        let cached = CachedNarration(audioData: audio, wordTimings: timings)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: cacheURL(key: key))
    }
}

// MARK: - Error

enum NarrationError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid ElevenLabs URL"
        case .httpError(let code): "ElevenLabs API error: HTTP \(code)"
        case .invalidResponse: "Invalid response from ElevenLabs"
        }
    }
}
