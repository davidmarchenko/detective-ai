# Murder Mystery: AI Detective Game

**Video call AI suspects. Catch them lying. Solve the case.**

An iOS game where you interrogate AI-powered characters in real-time video calls to solve a murder mystery. Built on [Runway's Characters API](https://docs.dev.runwayml.com/characters/) — the suspects are live AI avatars that see you, hear you, and respond naturally. Your job is to crack them.

## How It Works

You're the detective. A murder has occurred at Villa Morada, and three suspects are waiting in the interrogation room. You video-call each one, ask questions with your voice, and try to catch the killer before time runs out.

**The suspects will:**
- Lie to your face
- Get nervous when you're onto something
- Contradict themselves if you press hard enough
- Point fingers at each other
- Eventually break — if you ask the right questions

**The game helps you by:**
- Suggesting questions based on what's been said (powered by an AI "Game Master" running in parallel)
- Detecting clues and contradictions in real-time from the conversation
- Showing "detective instinct" hints when something feels off
- Tracking a suspicion meter that fills as the suspect gets evasive
- Letting you review evidence between interrogations

## The Tech Stack

```
┌──────────────────────────┐
│      iOS App (Swift)     │
│  SwiftUI + LiveKit SDK   │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│     Backend Proxy        │  ← API keys stay server-side
│   Serverless Functions   │
└──────────┬───────────────┘
           │
     ┌─────┼──────────┐
     ▼     ▼          ▼
  Runway  OpenAI  ElevenLabs
 (Avatar) (Game   (Narration)
          Master)
```

- **[Runway Characters API](https://docs.dev.runwayml.com/characters/)** — Real-time AI avatar video calls via LiveKit. Each suspect is a custom avatar with a unique face, voice, and personality. The personality prompt defines their backstory, secrets, and behavioral triggers.
- **[OpenAI GPT-4o-mini](https://platform.openai.com/docs/models)** — Runs as a "Game Master" analyzing the conversation transcript in real-time. Detects when a suspect reveals a clue, catches contradictions, generates contextual follow-up questions, and provides "detective instinct" hints.
- **[ElevenLabs](https://elevenlabs.io)** — Text-to-speech narration for the case briefing with word-by-word karaoke-style highlighting.
- **[LiveKit](https://livekit.io)** — WebRTC transport layer. Runway uses LiveKit under the hood for all real-time audio/video. The iOS app connects directly to LiveKit rooms using the [Swift SDK](https://github.com/livekit/client-sdk-swift).
- **Backend Proxy** — Serverless functions that hold all API keys server-side. The iOS app only has a revocable app token — no direct API access.

## The Game Flow

```
📋 Case Briefing          Read (or listen to) the crime details
    ↓                     Narrated by ElevenLabs TTS
👤 Suspect Board          Pick who to interrogate
    ↓                     Sessions pre-created for fast connect
🎥 Video Interrogation    Talk to the AI suspect in real time
    ↓                     Game Master analyzes every response
📎 Evidence Board         Review clues and contradictions
    ↓                     Organized by investigation line
🔴 Accusation             Pick the killer and state the motive
    ↓
⚖️ Verdict                Score breakdown + dramatic reveal
```

## What Makes This Interesting

### The Avatar Does NOT Drive the Game

Early versions relied on the Runway avatar to fire "tool calls" when it revealed clues. This was unreliable — the avatar is focused on being a convincing character, not a game engine. The breakthrough was adding a **separate AI layer** (OpenAI) that listens to the conversation and independently detects game events:

```
Avatar speaks → LiveKit transcription → GPT-4o-mini analysis → Game events
```

The avatar just acts. The Game Master scores.

### Reverse-Engineered from the React SDK

Runway only provides a [React web SDK](https://github.com/runwayml/avatars-sdk-react). This iOS app was built by reverse-engineering the SDK's source code to map out:
- REST API endpoints (`POST /v1/realtime_sessions`, polling, `/consume`)
- The two-tier auth model (API key → session key → LiveKit token)
- The fact that it's all LiveKit under the hood (not raw WebRTC)

This meant we could use the [LiveKit Swift SDK](https://github.com/livekit/client-sdk-swift) directly — no React Native bridge needed.

### Personality Prompts as Game Design

Each suspect's entire behavior is defined in a ~1500 character personality prompt. The prompt encodes:
- Their backstory and relationship to the victim
- What they know (and what they're hiding)
- Specific behavioral triggers ("if asked about art, get nervous")
- When to deflect vs. when to crack
- Explicit contradictions they'll make under pressure

The scenario is a JSON file — new mysteries can be added without code changes.

## Areas for Improvement

### Prompt Reliability
The suspects don't always behave as instructed. Runway's 2000-character personality limit means we can't be as detailed as we'd like about behavioral triggers. More testing and prompt iteration would help. A "prompt testing harness" that runs the same questions against a suspect 10 times and checks for consistency would be valuable.

### Clue Detection Accuracy
The Game Master (GPT-4o-mini) sometimes hallucinates clues that weren't actually revealed, or misses ones that were. Using a more capable model (GPT-4o) would help but adds latency and cost. A hybrid approach — using keyword matching for obvious clues and LLM analysis for subtle ones — would be more robust.

### Transcription Quality
LiveKit's built-in transcription is the source of truth for the Game Master. If the transcription is wrong, the analysis is wrong. Integrating a dedicated STT service (Deepgram, AssemblyAI) with higher accuracy could improve clue detection significantly.

### Session Startup Time
There's a ~10 second cold start when entering a call (Runway allocating a GPU for the avatar). Pre-warming sessions during the briefing screen was attempted but caused race conditions with session consumption. A more robust pre-warming approach (or Runway adding warm pools) would eliminate this.

### Multi-Mystery Scalability
Currently there's one scenario ("The Vanishing Act at Villa Morada"). The data model supports unlimited scenarios via JSON files, but each mystery requires 3 custom Runway avatars with unique faces and voices. A "mystery editor" tool that generates scenario JSON + avatar creation would make this scalable.

### Conversation Memory Across Suspects
In standard play (3 suspects), the player can use clues from one suspect to pressure another. But the avatar doesn't know what other suspects said — it only has its own personality prompt. Injecting cross-suspect evidence into the personality prompt at session creation time would enable more dynamic interrogations.

### Offline Mode
Everything requires network. A local LLM (on-device via CoreML) could handle the Game Master analysis offline, and pre-recorded avatar responses could enable a fully offline demo mode.

## Project Structure

```
Runway Characters/
├── Runway_CharactersApp.swift     App entry point
├── ContentView.swift              Root view → MysteryGameView
├── Config.swift                   Backend URL + app auth token
├── RunwayAPI.swift                REST client (via backend proxy)
├── SessionManager.swift           LiveKit room + session lifecycle
│
├── Game/
│   ├── GameMasterService.swift    AI conversation analyzer (OpenAI)
│   ├── GameTools.swift            Tool definitions for avatar events
│   ├── NarrationService.swift     TTS briefing narration (ElevenLabs)
│   │
│   ├── Models/
│   │   ├── MysteryScenario.swift  Codable models + scenario loader
│   │   └── GameState.swift        Observable game state machine
│   │
│   ├── Views/
│   │   ├── MysteryGameView.swift      Phase router
│   │   ├── MysteryLobbyView.swift     Case selection
│   │   ├── CaseBriefingView.swift     Narrated case file
│   │   ├── SuspectBoardView.swift     Pick suspects
│   │   ├── InterrogationView.swift    Video call + game HUD
│   │   ├── InvestigationDrawerView.swift  Lines/Questions/Actions
│   │   ├── EvidenceBoardView.swift    Clue review
│   │   ├── CaseNotebookView.swift     Mid-call reference
│   │   ├── AccusationView.swift       Final accusation
│   │   └── VerdictView.swift          Score + reveal
│   │
│   └── Scenarios/
│       └── mystery_villa_morada.json  "The Vanishing Act at Villa Morada"
│
└── backend/                       Serverless API proxy
    └── api/
        ├── _auth.js               Shared auth middleware
        ├── session/create.js      → Runway session creation
        ├── session/[id]/status.js → Runway session polling
        ├── session/[id]/consume.js→ Runway session consume
        ├── openai/analyze.js      → OpenAI chat completions
        └── tts/speak.js           → ElevenLabs TTS streaming
```

## Setup

**Prerequisites:** Xcode 26+, iOS 18+, Node.js 18+

1. Clone the repo
2. Open `Runway Characters.xcodeproj` in Xcode
3. Add the [LiveKit Swift SDK](https://github.com/livekit/client-sdk-swift) package dependency (File → Add Package Dependencies)
4. Create custom avatars on [dev.runwayml.com](https://dev.runwayml.com) and update the avatar IDs in `mystery_villa_morada.json`
5. Deploy the backend to any serverless platform — set the required environment variables (see `backend/api/_auth.js` for the auth pattern)
6. Update `Config.swift` with your backend URL and app auth token
7. Build and run on a physical device (camera/mic required)

## License

MIT
