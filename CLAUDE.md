# CLAUDE.md — Sanscore

Context for working on this project in Claude Code.

## What this is

**Sanscore** — an iOS + watchOS party game (Apple Developer Academy, Challenge 4).
A "truth or lie" game: one player answers a question out loud, the app measures
them and shows a fun **sus meter** (Truth / Hmm / Liar). **Entertainment only —
not a real lie detector.** This framing is deliberate: it dodges medical/accuracy
claims and keeps App Store review happy. Keep an "entertainment only" disclaimer
in the UI.

Face-to-face group play (4–5 people), everyone on their own iPhone, joining a
local room. Target hardware: **iPhone 17** (all have Apple Intelligence).

## How the game scores (the core idea)

Four signals are captured during one answer, each normalized to 0–1 (deviation
from the player's own calibration **baseline**), then fused by a **weighted sum**
into one sus score. LLM judges meaning; math judges everything else.

```
susScore = 0.3·hr + 0.2·responseTime + 0.2·speechRate + 0.3·structure
```

| Signal | Source | Tool |
|--------|--------|------|
| Heart rate | camera PPG (finger + torch), Apple Watch later | math |
| Response time | timer: "done asking" → first word | math |
| Speech rate | words ÷ duration from `SFSpeechRecognizer` | math |
| Answer structure (evasive/vague) | the transcript text | **Foundation Models LLM** |

Key rules that were decided and should NOT be re-litigated:
- **No CoreML.** No training data exists; a weighted sum + one LLM call covers it.
- **LLM reads TEXT only.** `SFSpeechRecognizer` transcribes audio → String → LLM.
  The same transcript feeds both speech-rate math and the LLM.
- **Speech rate is arithmetic**, not the LLM's job.
- **On-device only.** No server. Voice/HR never leave the phone. Privacy by design.
- Rooms are **local** (MultipeerConnectivity), same-room only. No backend, no
  internet. Only the `RoundResult` (name + score + verdict) travels between phones.

## Architecture

Protocol-driven so the logic runs on mocks today and real modules swap in with
zero rewrite. UI reads a `@Observable GameViewModel` and computes nothing itself.

```
signals (protocols) → SusEngine (fuse) → GameViewModel → SwiftUI
```

Protocols: `HeartRateSource`, `SpeechCapturing`, `StructureAnalyzing`. Each has a
mock (runs in Simulator) and a real iOS implementation.

## Where the code lives

Open `Sanscore/Sanscore.xcodeproj`. Source of truth is inside it:

```
Sanscore/Sanscore/
  Shared/Models/Models.swift            data types, SusBand, GameState, RoundResult
  Shared/Services/SusEngine.swift       the brain (weighted-sum fusion)
  Shared/Services/Interfaces.swift      the protocols
  Shared/Services/Mocks.swift           fake sensors (Simulator)
  Shared/Services/StructureAnalyzer.swift  LLM, iOS 26+, #if canImport(FoundationModels)
  Shared/Services/RealSpeechCapture.swift  SFSpeechRecognizer, iOS
  Shared/Services/RealHeartRate.swift      camera PPG, iOS
  Shared/Connectivity/RoomService.swift    MultipeerConnectivity, iOS
  SanscoreiOS/ViewModels/GameViewModel.swift  the bridge; UI reads this
  SanscoreiOS/Views/GameFlowView.swift     the real UI: all screens, switches on vm.state
  SanscoreiOS/Views/RoomBrowserView.swift  "Join room" — Apple's MCBrowserViewController
  SanscoreiOS/App/SanscoreApp.swift        @main -> GameFlowView()
Tests/SusEngineXCTests.swift            add to a Unit Test target, Cmd+U
Tests/SusEngineTests.swift              command-line version of the same asserts
```

(`DevTestView.swift` is deleted — `GameFlowView` is the real screen now.)

Note: this diverges from `STRUCTURE.md` (which planned `Shared/` at the repo
root for iOS+Watch sharing). Code currently lives inside the Xcode project. When
the Watch target is added, give `Shared/` files membership in both targets.

## UI flow (GameFlowView switches on GameState)

```
idle (create/join room) → roomLobby → roleReveal (roulette)
   → asker:     asking (push-to-talk) → waitingForResult → result
   → answerer:  answering (push-to-talk) → loading → calculating → result
   → spectator: spectating → result
```

- `GameState` cases live in `Models.swift`: idle, calibrating, roomLobby,
  roleReveal, asking, answering, spectating, waitingForResult, loading,
  calculating, result. `PlayerRole`: asker / answerer / spectator.
- Push-to-talk: hold anywhere on screen to talk, release to finish.
  - Asker releases → `.waitingForResult` (waits for answerer's broadcast).
  - Answerer press → response-time clock stops + speech starts; release →
    `.loading` (HR + transcribe) → `.calculating` (LLM + fuse) → `.result`.
- Response time is measured from asker-release → answerer-press timestamps
  (not the old "done asking → first word"), held in `GameViewModel`.
- **Dev override:** `#if DEBUG` buttons in the lobby ("Asker/Answerer/Spectator")
  force your role via `startSession(forcedRole:)` so you can test each role
  without the dice. Not compiled into release builds.
- `.waitingForResult` and `.spectating` have a "Back" button → `backToStart()`
  → `.idle`, because neither resolves without a partner device (see below).

## Current state

- Logic base code complete and tested (`SusEngine` math verified).
- **Real UI built** (`GameFlowView`), runs the full flow above.
- **Sensor swap in progress** (see "Sensor swap" below):
  - Speech = **real** (`RealSpeechCapture`) — step 1 done. Needs a real iPhone;
    won't transcribe in the Simulator.
  - Heart rate + structure (LLM) = still **mock**.
- Mocks now have artificial delays (`Task.sleep`) so the loading/calculating
  screens are actually visible instead of flashing past.
- Multiplayer NOT working: `RoomService` connects + broadcasts `RoundResult`,
  but turn-order sync (who's asker/answerer, the question) is not built — each
  phone rolls its own role locally. Real 2-device play doesn't coordinate yet.

## Team + ownership

- **Pafras** (lead) — SusEngine, ViewModel, integration, async/hardware modules
  (speech, camera PPG, room). Stronger coder.
- **Agung** (beginner) — `StructureAnalyzer.swift` LLM (fill the `TODO(agung)`:
  `@Generable` fields + prompt). Text in, score out; never touches audio.
- **Marleen** (beginner) — `SusEngine.swift` tuning (`TODO(marleen)`: weights,
  sensitivity, real calibration baseline) + keep the tests green.
- **Satria** — design only (Figma), no code.

Beginners get isolated, spec'd, testable tasks behind protocols. Lead owns the
async/hardware/integration. See `HANDOFF.md`.

## Conventions

- Logic files never `import SwiftUI`. UI reads `GameViewModel`, computes nothing.
- iOS-only files are `#if os(iOS)` / `#if canImport(...)` guarded so the project
  compiles even where a framework is missing.
- Deliberate shortcuts are marked `// ponytail:` with the ceiling + upgrade path.
  Beginner tasks are marked `// TODO(agung)` / `// TODO(marleen)`.
- Comments are written for beginners — explain the why, not just the what.

## Known deliberate shortcuts (ponytail:)

- Speech: 300 ms wait for the final transcript instead of awaiting `isFinal`.
- Camera PPG: zero-crossing pulse count on a detrended signal (± a few BPM, fine
  for a game) instead of bandpass + FFT.
- Room: broadcasts results only — the turn-order state machine is not built yet.
- No App Store fallback for non-Apple-Intelligence devices (all users are iPhone
  17). `structure` is a plain `Double`; make it optional + add an availability
  guard when shipping to older devices.

## Sensor swap (mocks → real, ONE AT A TIME)

Edit `GameViewModel.init` defaults, `Cmd+R` on a real device, test, then next.
Rule: never swap two at once — if it breaks you won't know which.

1. **Speech → `RealSpeechCapture()`** — DONE. Mic + speech permission is
   requested up front in `RoomSetupView.task` (`RealSpeechCapture.requestPermission()`).
2. **Heart rate → `RealHeartRate()`** — TODO. Grant camera. See gotcha below.
3. **Structure → `StructureAnalyzer()`** — TODO, needs Agung's file finished +
   an iOS 26 Apple-Intelligence device.

Put `MockSpeech()` back in the init if you need to demo on the Simulator.

### Two known design gotchas (flag, don't silently fix)
- **HR is captured ~12s AFTER the answer** (a fresh separate `RealHeartRate`
  capture), so the loading screen becomes ~12s and HR is read post-stress, not
  during. Also needs a finger on the back camera + torch while the person is
  talking into the mic — physically awkward. Real fix later: capture HR *during*
  the answer.
- **The asker's question is spoken, not transcribed** (we removed typing), so
  `currentQuestion` stays "". `MockStructure` ignores it; the real
  `StructureAnalyzer` will get an empty question and judge the answer alone.

## Testing & hardware notes

- **Simulator**: UI + mock flow only, AND only if speech is set back to
  `MockSpeech()` (RealSpeechCapture needs a device).
- **Real iPhone 17** needed for: camera PPG, real mic speech, Foundation Models
  LLM, and (×2 devices) the room.
- **Info.plist keys are already set** as `INFOPLIST_KEY_*` build settings in
  `project.pbxproj` (the project uses `GENERATE_INFOPLIST_FILE = YES`, no manual
  Info.plist): `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`,
  `NSCameraUsageDescription`, `NSLocalNetworkUsageDescription`. `NSBonjourServices`
  is an array — build settings can't hold it cleanly, so add it in Xcode's Info
  tab (`_sanscore._tcp`, `_sanscore._udp`) only when testing real rooms.

## Git

Branch `dev` (integration). Per `STRUCTURE.md`: branch off `dev`
(`feat/ios-*`, `feat/shared-*`, `feat/watch-*`), small PRs, merge back to `dev`.
Nothing from this logic base is committed yet.

## Likely next steps

Today's goal: **single-phone real sensors** (skip multiplayer for now).

1. Test speech (step 1, done) on a real device — answerer role, hold-talk-release,
   confirm the real transcript feeds the score.
2. Swap heart rate (step 2) → test. Then structure/LLM (step 3) once Agung's done.
3. **Agung:** finish the 3 `TODO(agung)` in `StructureAnalyzer.swift` — the file is
   mostly written (fields + prompt + scoring exist); it's *tuning* the persona,
   prompt wording, and the evasiveness/vagueness weights, not building from
   scratch. He can't test without a real iPhone 17, so he tweaks on paper + hands
   the file to Pafras for step 3.
4. **Marleen:** `SusEngine.swift` weight/sensitivity tuning + keep tests green.
5. Later: room turn-order sync (the real multiplayer gap), then Apple Watch HR (v2).
