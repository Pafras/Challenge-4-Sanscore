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
  Shared/Extensions/UIImage+Thumbnail.swift  shrink camera photo -> tiny JPEG avatar
  Shared/Connectivity/RoomService.swift    MultipeerConnectivity, iOS
  SanscoreiOS/ViewModels/GameViewModel.swift  the bridge; UI reads this
  SanscoreiOS/Views/GameFlowView.swift     the real UI: all screens + lobby bubbles
  SanscoreiOS/Views/CameraPicker.swift     UIImagePickerController wrapper (lobby selfie)
  SanscoreiOS/App/SanscoreApp.swift        @main -> GameFlowView()
  Info.plist                               NSBonjourServices (rooms) + usage strings
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
  call `vm.forceRole(_:)` to force this device's role for solo screen testing.
  Not compiled into release builds.
- `.waitingForResult` and `.spectating` have a "Back" button → `backToStart()`.

## Multiplayer (turn-order sync — WORKING)

Real face-to-face multiplayer over MultipeerConnectivity. Tested on 2 Simulators.

- **`RoomMessage`** enum (`Models.swift`) = one envelope for everything that
  crosses the network: `.turn(asker,answerer)`, `.question(String)`,
  `.result(RoundResult)`, `.profile(name,Data)` (avatar), `.rename(id,display)`
  (chosen name). `RoomService.send(_:)` / `onMessage` is the single path.
- **Host** = whoever taps "Create room" (`isHost = true`). Host generates a
  **4-digit room code**, shown in the lobby. `NSBonjourServices` is set in
  `Info.plist` (`_sanscore._tcp/_udp`) — required for discovery on real devices.
- **Join** = custom nearby list (`RoomService.foundRooms` via `MCNearbyServiceBrowser`)
  → tap a room → **enter the code** → `join(host, code:)` sends it as the invite
  context → host's advertiser accepts only on match. Host's chosen name rides in
  the advertiser's discoveryInfo (`roomNames`), so the list shows it, not "iPhone".
  `startBrowsing` restarts the browser so a re-browse re-finds existing rooms.
  (Replaced `MCBrowserViewController`; `RoomBrowserView.swift` deleted.)
- **Identity vs display name**: the `MCPeerID` name (device name) is the stable
  id used as the key everywhere (turns, avatars, `currentAsker/Answerer`). The
  shown label is a separate broadcast (`displayNames`, `label(for:)`), so a player
  can rename ANY time — even mid-lobby — via `setDisplayName`, no reconnect.
- **Turns**: host `startSession()` picks asker+answerer round-robin from
  `room.players` (sorted names), broadcasts `.turn`, applies locally (host plays
  too). Every device's `applyTurn` matches its own name → asker/answerer/spectator.
- **Question relay**: asker release → `send(.question)` → answerer's `setQuestion`.
- **Result**: answerer scores → `send(.result)` → asker + spectators show it.
- **"Start"/"Next round"** = `vm.start()`/`nextRound()`: host → `startSession`;
  solo (no peers) → `startRound()` single-phone loop. Non-host clients wait — the
  result screen shows "waiting for host" (only host/solo can advance, `canAdvance`).

### Lobby (waiting room)
- Players shown as drifting **avatar bubbles** (`PlayerBubblesView`): photo or
  initials, your own ringed with a camera badge. Tap your bubble → `EditProfileView`
  (take/retake photo via `CameraPicker`, edit name).
- Avatars = tiny JPEG thumbnails (`UIImage+Thumbnail`) broadcast via `.profile`.
- **Leave** = top-left chevron → confirmation dialog (host: "closes room";
  player: "leave"). Leaver sees "You left the room" on start; others get an
  "X left" toast.

### Disconnect handling
- **Host leaves** → room closes → everyone to start screen (`endRoom`), alert shown.
- **Active asker/answerer leaves** → round can't finish → `returnToLobby` (room
  stays alive, host restarts). Tracked via `currentAsker`/`currentAnswerer`.
- **Spectator/other leaves** → game keeps going, transient toast "X left"
  (`leftNotice`, auto-clears 3s).
- **Silent stall backstop**: `armResultTimeout(30s)` → back to lobby if no result.

## Current state

- Logic base tested (`SusEngine`), **real UI** (`GameFlowView`), **multiplayer + room
  code working** (tested device↔Simulator), **calibration** (3-question averaged
  baseline, shows your BPM), **lobby profiles** (avatar bubbles + editable names).
- **All sensors real**: speech, camera heart rate, AND the LLM. `GameViewModel.init`
  auto-picks real on device / mock on Simulator; the LLM (`StructureAnalyzer`) is
  gated `#if canImport(FoundationModels)` + `if #available(iOS 26)`, mock otherwise.
  Agung's tuned analyzer (evasiveness/vagueness/timidity/incoherence) is live.
- **Signing is per-developer** — `Config/Signing.xcconfig` (committed) optionally
  includes `Config/Local.xcconfig` (git-ignored) where each dev sets their own
  `DEVELOPMENT_TEAM` + `PRODUCT_BUNDLE_IDENTIFIER`. Copy `Local.example.xcconfig`
  → `Local.xcconfig` on a fresh clone. Never commit signing to `project.pbxproj`.
- **Simulator auto-uses mocks**, device auto-uses real (`#if targetEnvironment(simulator)`
  in `GameViewModel.init`) — so 2-Simulator multiplayer testing runs with no hardware.
- Mocks have `Task.sleep` delays so loading/calculating screens are visible.
- HR: camera PPG, ~30fps, moving-average detrend + zero-crossing. ±10-15 BPM
  jitter (accepted — party game). Capture is 8s AFTER the answer (loading screen
  has a countdown ring); real fix later = capture during the answer.

## Team + ownership

- **Pafras** (lead) — SusEngine, ViewModel, integration, async/hardware modules
  (speech, camera PPG, room). Stronger coder.
- **Agung** (beginner) — `StructureAnalyzer.swift` LLM: **DONE** (fields + prompt +
  weights tuned, live on device). Next: helping Marleen slice the UI front end.
- **Marleen** (beginner) — front-end UI slicing (with Agung). Was down for
  `SusEngine.swift` tuning; UI is the current focus.
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
- Camera PPG: moving-average detrend + zero-crossing pulse count (± ~10-15 BPM,
  fine for a game) instead of bandpass + FFT.
- No App Store fallback for non-Apple-Intelligence devices (all users are iPhone
  17). `structure` is a plain `Double`; make it optional + add an availability
  guard when shipping to older devices.
- HR captured AFTER the answer (see gotcha below), not during.

## Sensor swap (mocks → real)

`GameViewModel.init` auto-picks: **real on device, mock on Simulator** (via
`#if targetEnvironment(simulator)`). No manual flipping. Pass explicit modules to
override. Only the LLM default is still `MockStructure` — swap to
`StructureAnalyzer()` in the init once Agung's file is merged (needs an iOS 26
Apple-Intelligence device to actually run).

- **Speech** (`RealSpeechCapture`) — DONE. Mic + speech permission requested up
  front in `RoomSetupView.task`.
- **Heart rate** (`RealHeartRate`) — DONE. Camera PPG, 30fps, torch, needs a
  finger on the back camera during the 8s loading screen.
- **Structure/LLM** (`StructureAnalyzer`) — still mock, waiting on Agung.

### Two known design gotchas (flag, don't silently fix)
- **HR is captured ~8s AFTER the answer** (a fresh `RealHeartRate` capture on the
  loading screen with a countdown ring), so HR is read post-stress, not during.
  Needs a finger on the back camera + torch. Real fix later: capture HR *during*
  the answer.
- **The asker's question IS now transcribed** (option A): asker holds to speak
  the question → `RealSpeechCapture` transcribes it → `setQuestion` → sent to the
  answerer's phone via `.question`. So the real `StructureAnalyzer` will get the
  question text. (Solo single-phone: same device asks then answers.)

## Testing & hardware notes

- **Simulator**: full UI + multiplayer testing works (auto-mocks sensors). Run 2
  Simulators to test rooms/turn-order. MultipeerConnectivity sim-to-sim is
  sometimes flaky; if a room isn't found, use 1 sim + a real iPhone.
- **Real iPhone 17** needed for: camera PPG, real mic speech, Foundation Models LLM.
- **Info.plist is a real file now** (`Sanscore/Info.plist`, `INFOPLIST_FILE` set):
  holds the mic/speech/camera/local-network/photo usage strings AND
  `NSBonjourServices` (`_sanscore._tcp` / `_sanscore._udp`) — **required** for
  MultipeerConnectivity discovery on real devices.

## Git

Branch `dev` (integration), pushed to `origin` (github.com/Pafras/Challenge-4-Sanscore).
Per `STRUCTURE.md`: branch off `dev`, small PRs, merge back to `dev`. The whole
project (incl. the Xcode `.xcodeproj`) lives in the ONE repo now — the nested
`Sanscore/.git` was removed so everything tracks together.

## Likely next steps

Logic + all real sensors + LLM = DONE. Focus shifts to the UI front end.

1. **Agung + Marleen:** slice/build the UI front end from Satria's design. All
   screens currently live in ONE file (`GameFlowView.swift`) — if two people edit
   it at once, merge conflicts. Ask Pafras (this session) to split it into
   per-screen files if that starts hurting. Keep the "logic files never import
   SwiftUI / UI computes nothing" rule.
2. **Satria:** deliver design → they restyle the screens.
3. **TEMP to restore:** the solo single-phone loop (`startRound`) is kept for
   1-device testing; real play uses host round-robin (`startSession`). Fine as-is.
4. Later polish: capture HR *during* the answer (not after); 3-endpoint disconnect
   testing; running scoreboard across rounds; Apple Watch HR (v2).
