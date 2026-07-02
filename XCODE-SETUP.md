# Xcode setup — Sanscore

The `.swift` files are written and the logic is tested. Xcode just needs a
project to hold them. ~10 minutes.

## 1. Make the project

- Xcode → New → Project → iOS → App.
- Product Name: **Sanscore**  (matches `@testable import Sanscore` in the tests).
- Interface: SwiftUI. Language: Swift.
- Save it INTO this folder (`Challenge 4- Sanscore`). Let it create the
  `Sanscore.xcodeproj`.
- Delete the auto-generated `ContentView.swift` and the default `App.swift`
  (we already have `SanscoreApp.swift` + `DevTestView.swift`).

## 2. Add the files

Drag these into the Project navigator (check "Copy items if needed" is OFF —
they already live here — and add to the **Sanscore** target):

```
Shared/Models/Models.swift
Shared/Services/SusEngine.swift
Shared/Services/Interfaces.swift
Shared/Services/Mocks.swift
Shared/Services/StructureAnalyzer.swift
Shared/Services/RealSpeechCapture.swift
Shared/Services/RealHeartRate.swift
Shared/Connectivity/RoomService.swift
SanscoreiOS/ViewModels/GameViewModel.swift
SanscoreiOS/Views/GameFlowView.swift
SanscoreiOS/App/SanscoreApp.swift
```

## 3. Info.plist keys

Add these (Project → target → Info):

| Key | Value | Needed by |
|-----|-------|-----------|
| `NSMicrophoneUsageDescription` | Hear your answer. | speech |
| `NSSpeechRecognitionUsageDescription` | Turn your answer into text. | speech |
| `NSCameraUsageDescription` | Read your heartbeat from your fingertip. | camera PPG |
| `NSLocalNetworkUsageDescription` | Find nearby players to join your room. | rooms |
| `NSBonjourServices` | array: `_sanscore._tcp`, `_sanscore._udp` | rooms |

## 4. Run

- Pick an iOS Simulator → Run.
- The app opens `DevTestView`. Tap **Run one round** → shows a mocked
  `Liar` / `0.80` / verdict. **Proves the whole pipeline with no hardware.**

## 5. Swap mocks for real (on a real iPhone 17)

In `GameViewModel.init` defaults, change:

```swift
heart: HeartRateSource = RealHeartRate(),        // was MockHeartRate()
speech: SpeechCapturing = RealSpeechCapture(),   // was MockSpeech()
structure: StructureAnalyzing = StructureAnalyzer()  // was MockStructure() — Agung finishes this
```

Do these ONE AT A TIME on a real device, testing after each. Camera + speech
+ Foundation Models don't work in the Simulator.

## 6. Tests (Cmd+U)

- File → New → Target → Unit Testing Bundle (name: SanscoreTests).
- Add `Tests/SusEngineXCTests.swift` to that test target.
- Cmd+U → 5 tests pass.
- (`Tests/SusEngineTests.swift` is the command-line version — leave it out of
  the app + test targets.)

## Target membership note

If/when you add the Watch target: `Shared/` files get **both** iOS + Watch,
EXCEPT `RealSpeechCapture.swift`, `RealHeartRate.swift`, `StructureAnalyzer.swift`,
`RoomService.swift`, and everything in `SanscoreiOS/` → **iOS only**. They are
`#if os(iOS)` guarded, so it still compiles either way, but keep them off Watch.
