# Sanscore — logic base code (handoff)

Everything here is pure logic. No UI, no networking yet. The **whole game flow
already runs on mock sensors**, so you can build your real module behind its
protocol and drop it in with zero changes elsewhere.

## Files (live INSIDE the Xcode project)

Source of truth = `Sanscore/Sanscore/`. Open `Sanscore/Sanscore.xcodeproj`.

| File | Path (under `Sanscore/Sanscore/`) | Owner |
|------|------|-------|
| `Models.swift` | `Shared/Models/` | Pafras |
| `SusEngine.swift` | `Shared/Services/` | Pafras / **Marleen tunes** |
| `Interfaces.swift` | `Shared/Services/` | Pafras |
| `Mocks.swift` | `Shared/Services/` | Pafras |
| `StructureAnalyzer.swift` | `Shared/Services/` (iOS only) | **Agung** |
| `RealSpeechCapture.swift` | `Shared/Services/` (iOS only) | Pafras |
| `RealHeartRate.swift` | `Shared/Services/` (iOS only) | Pafras |
| `RoomService.swift` | `Shared/Connectivity/` (iOS only) | Pafras |
| `GameViewModel.swift` | `SanscoreiOS/ViewModels/` | Pafras |
| `DevTestView.swift` | `SanscoreiOS/Views/` | Pafras (throwaway) |
| `SusEngineXCTests.swift` | `Tests/` (add to a Unit Test target) | Marleen keeps green |

Note: this diverges from the original `STRUCTURE.md` (which put `Shared/` at the
repo root for iOS+Watch sharing). For a single iOS target this is fine; when the
Watch target is added, give the `Shared/` files membership in both targets.

## Run the math test

Option A — in Xcode: add `Tests/SusEngineXCTests.swift` to a Unit Testing
Bundle target, then Cmd+U.

Option B — command line, from repo root:

```
cd "Challenge 4- Sanscore"
cp Tests/SusEngineTests.swift Tests/main.swift
swiftc Sanscore/Sanscore/Shared/Models/Models.swift Sanscore/Sanscore/Shared/Services/SusEngine.swift Tests/main.swift -o /tmp/sanscoretest && /tmp/sanscoretest
rm Tests/main.swift
```

Should print `All SusEngine tests passed.`

## Agung — your job (StructureAnalyzer.swift)

The LLM reads the answer TEXT and scores how evasive/vague it is + writes a
funny verdict. The skeleton is written. Look for `TODO(agung)`:

1. Add/adjust the `@Generable` struct fields (each `@Guide` = what a number means).
2. Tune the `instructions` persona + the `prompt`.
3. Decide how the fields combine into one 0-1 `score`.

You never touch audio — you get the transcript String already. Only text in,
`StructureResult` out. Needs iOS 26 + a real iPhone 17 to run (Foundation Models).

## Marleen — your job (SusEngine.swift + tests)

The engine works, but the `weights` and `sensitivity` numbers are first
guesses. Look for `TODO(marleen)`:

1. During playtest, watch which answers score too high / too low.
2. Adjust `SusWeights` (must sum to 1.0) and `SusSensitivity`.
3. Re-run the test, update the expected numbers to match the new design.
4. Later: fill the real `baseline` from the calibration round (easy questions).

## The contract (for the UI, built next)

The UI only reads these from `GameViewModel` and shows them — it computes nothing:

- `vm.state` — which screen (idle / calibrating / asking / answering / calculating / result)
- `vm.lastResult` — `SusResult` (score, band, verdict) for the meter
- `vm.currentQuestion` — the question text

## Not built yet (Pafras, later)

- Real `HeartRateSource` (camera PPG, then Apple Watch)
- Real `SpeechCapturing` (SFSpeechRecognizer)
- `RoomService` (MultipeerConnectivity — build the single-phone game first)
