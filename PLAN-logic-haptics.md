# PLAN — Logic retune + Haptics

Discussion doc. Nothing built yet. Decide with team, then Pafras + Claude implement.
All changes are logic/UI-feel only — no conflict with Marleen/Agung layout push.

---

## Part A — SusEngine retunes

File: `Sanscore/Sanscore/Shared/Services/SusEngine.swift`
Tests exist (`Tests/SusEngineTests.swift`) — run after each change to prove nothing breaks.

### A1. HR one-directional (correctness) — SMALL
**Problem:** `normalize()` uses `abs(value - baseline)` (line 40). For heart rate that
means dropping BELOW baseline counts as sus, same as spiking above. Wrong — a calm/
relaxed player isn't lying. Only HR ABOVE baseline = stress = sus.
**Fix:** one-directional for HR only → `max(value - baseline, 0)`.
ResponseTime + speechRate KEEP `abs()` (too-fast AND too-slow both sus there).
**Cost:** ~3 lines. Own-file. Risk: low.

### A2. Reweight — noisiest signal shouldn't dominate (feel) — SMALL, needs playtest
**Problem:** HR weight = 0.3 (tied highest, line 15). But HR is the LEAST reliable
signal: camera PPG ±10-15 BPM jitter AND captured 8s AFTER the answer (post-stress,
known gotcha). Weighting the noisiest signal highest makes the meter feel random.
**Fix (proposed):** drop HR, raise structure (the LLM = smartest signal):
```
hr 0.2 · responseTime 0.2 · speechRate 0.2 · structure 0.4   (was 0.3/0.2/0.2/0.3)
```
**Cost:** 2 lines. BUT tune with real playtest data, not blind. Discuss numbers.

### A3. Renormalize by weight sum (safety) — SMALL
**Problem:** `SusWeights.sum` is computed (line 20) but never used. If anyone tunes
weights and they don't total 1.0, the score silently skews (just clamped at line 56).
**Fix:** divide `raw / weights.sum` before clamp. Then weights can be tweaked freely,
always lands 0-1. One line. Makes A2 (and Marleen's future tuning) safe.

### A4. Cross-round scoreboard (feature) — MEDIUM
**Gap:** game is one-shot per round. No running tally. Party game wants a
"biggest liar" leaderboard across rounds. (Already on CLAUDE.md next-steps #4.)
**Fix:** `[String: [Double]]` name→scores in `GameViewModel`; show leaderboard on
result screen. Touches ViewModel (ours) + result view (UI). After wiring lands.

**Order:** A1 + A3 first (tiny, correctness/safety, no playtest needed).
A2 after a playtest session. A4 is a feature — after identity-flow wiring.

---

## Part B — Haptics / vibration

Where to buzz, ranked by payoff. UI-layer only (logic files never import UIKit).

### B1. Result reveal — band-dependent (BIGGEST) 
`ResultView` appears → different haptic per `SusBand`:
- Truth → `.success` (soft)
- Hmm  → `.warning` (medium)
- Liar  → `.error` or `.impact(.heavy)` (hard)
Peak drama. Buzz sells the verdict before eyes read it.

### B2. Push-to-talk press + release
`askerPressed()` / `answererPressed()` → `.impact(.medium)` on press,
`.light` on release. Confirms "mic live / mic off" — players holding the whole
screen can't see a button state.

### B3. Role-reveal roulette
`RoleRevealView` spin → `.impact(.light)` tick each name-flip, `.rigid` on lock.
Slot-machine feel. High fun-per-effort.

### B4. Loading countdown ring
`LoadingView` 8s finger-on-camera ring → soft pulse each second, so player keeps
finger down without watching the screen.

### How — skip CoreHaptics (ponytail)
No `.ahap` patterns needed. Stdlib `UIFeedbackGenerator` covers all four, one line each:
```swift
UINotificationFeedbackGenerator().notificationOccurred(.error)   // result
UIImpactFeedbackGenerator(style: .medium).impactOccurred()       // press
```
Custom CoreHaptics `.ahap` ONLY if we want a signature "liar" pattern later.

### Where code lives
Called from UI on button press or `.onChange(of: vm.state)` — NOT in `GameViewModel`
(keeps the "logic files never import UIKit" rule). Either inline one-liners or a tiny
`Haptics.swift` helper in `Views/`.

**Priority:** B1 + B2 = highest payoff, ~4 one-liners. Do alongside the result/asking
views — same files the identity-flow wiring touches, so batch to avoid double-edit.

---

## Part C — Localization (min 2 languages) — REQUIRED

Challenge requirement: app must ship in **≥2 languages** (likely English + Indonesian).
Not built yet. Do after UI is stable (localizing a moving target = rework).

### How — String Catalog (modern, Xcode 15+)
1. New file → **String Catalog** (`Localizable.xccatalog`). Add EN + ID.
2. Wrap every user-facing string: SwiftUI `Text("...")` auto-localizes; for interpolated
   or non-Text strings use `String(localized:)`.
3. Xcode auto-extracts keys into the catalog → translate the ID column.
4. Info.plist usage strings (camera/mic/speech/local-network) — localize too (App Store shows them).

### Watch out — LLM output is NOT localized
`StructureAnalyzer` verdict lines ("Couldn't hear you...", the funny sus lines) come from
the LLM + one hardcoded fallback. Two options:
- Prompt the LLM in the user's locale (pass language into the prompt), OR
- Keep verdicts English-only for v1, localize just the UI chrome (buttons/labels/prompts).
Decide with team. Hardcoded fallback strings (GameViewModel) must be localized regardless.

### Scope estimate
UI chrome only = medium (wrap ~40-60 strings across the sliced view files). Full incl.
LLM = larger. Beginner-friendly task once views are frozen — good Agung/Marleen work.

---

## Part D — Accessibility (min 1 feature) — REQUIRED

Challenge requirement: ≥1 accessibility feature.

**⚠️ Dark mode is NOT an accessibility feature** (it's an appearance option). Graders
want VoiceOver / Dynamic Type / contrast / Reduce Motion. Do a real one; dark mode = polish.

### Pick (recommend): VoiceOver on the result / sus meter
The verdict is purely VISUAL (Truth/Hmm/Liar = color + position). Blind user gets nothing.
Add `.accessibilityLabel("Verdict: Liar, 82% sus")` on `Result` view → screen reader
announces it. ~5-10 lines, one file, genuinely useful. Best fit for this app.

### Alternatives
- **Dynamic Type** — text scales with system font size. Free IF using system fonts
  (`.font(.body/.title)`) not hardcoded `.system(size:)`. Canonical a11y feature.
- **Reduce Motion** — respect `@Environment(\.accessibilityReduceMotion)`, skip the
  role-reveal roulette spin for motion-sensitive users.

### Dark mode (polish, not the requirement)
Team wants it — fine, but counts as looks not a11y. Custom `CheckeredBackground` needs
color-adapting for dark. Use semantic colors (`Color(.systemBackground)`, `.primary`)
so both modes work. Medium effort with the custom bg. Do AFTER views frozen.

### When
VoiceOver labels = after views frozen (touches result view). Dynamic Type = audit for
hardcoded font sizes as views land. Both = beginner-friendly once layout stable.

---

## Part F — 4-band verdict (was 3) — SusBand redesign

Change `SusBand` from 3 bands to 4 for finer verdict. Score stays 0 (truth) → 1 (liar).

| SusBand case | score | label | color |
|---|---|---|---|
| `.truth` | 0.0–0.25 | "Truth" | green |
| `.leaningTruth` | 0.25–0.5 | "Leaning truth" | mint |
| `.leaningLiar` | 0.5–0.75 | "Leaning liar" | orange |
| `.liar` | 0.75–1.0 | "Liar" | red |

**Keep `.truth` / `.liar` case names** (only rename `.hmm` → split into two) → existing
tests (assert `.truth`, `.liar`) pass unchanged.

**Files touched (all Pafras's — no team conflict):**
- `Models.swift` — SusBand enum: 4 cases, new `init(score:)` thresholds, 4 labels.
- `RoundViews.swift` — `bandColor` + label switch: add 2 cases.
- Ripples: Part E clips 3→4, Part B1 haptic 3→4 (4 buzz intensities).

Safe to do anytime (own files). Tests survive. Do the enum now if wanted; UI colors/clips
after views frozen.

---

## Part E — Voice on result screen (fun, optional)

Play voice when `Result` appears. Pairs great with the band-dependent haptic (B1).

**⚠️ TTS ≠ recorded voice — pick one model:**
- Recorded clips (your voice) = warm/funny, but ONLY fixed lines (can't pre-record the
  dynamic LLM verdict).
- TTS (`AVSpeechSynthesizer`) = robot reads ANY text live, incl. the LLM line, no assets.

**Option A (CHOSEN) — recorded band stingers.** `AVAudioPlayer` plays the clip matching
`SusBand` when `Result` appears. ~10 lines, 3 assets, Pafras's voice = party energy.

Exact map (4-band SusBand — see Part F):
| SusBand | score | clip file | EN line | ID line |
|---|---|---|---|---|
| `.truth`        | 0.0–0.25  | `truth.m4a`        | "You're telling the truth!" | "Kamu jujur!" |
| `.leaningTruth` | 0.25–0.5  | `leaningTruth.m4a` | "You're leaning to the truth…" | "Kamu condong jujur…" |
| `.leaningLiar`  | 0.5–0.75  | `leaningLiar.m4a`  | "You're leaning to liar…" | "Kamu condong bohong…" |
| `.liar`         | 0.75–1.0  | `liar.m4a`         | "You're a LIAR!" | "Kamu BOHONG!" |

Impl: `switch vm.result.band` in `Result` view `.onAppear` → play the matching file.
A tiny `SoundPlayer` helper (holds the `AVAudioPlayer`, plays by band) in `Views/` keeps
it off the logic layer.

**Option B — TTS reads the actual verdict.** `AVSpeechSynthesizer` speaks the LLM's funny
line. Dynamic, no recording, but robotic.

**Option C — both:** recorded stinger THEN TTS reads the line. Most polish, most work.

**Assets:** Pafras records the clips (.m4a/.caf). Trigger from `Result` view `.onAppear`.
Volume/mute respect the silent switch (`AVAudioSession`).

**Localized audio (language switch flips voice too):** iOS localizes ANY resource by
`<lang>.lproj` folder — same filename, different folder:
```
en.lproj/liar.m4a  → "You're a LIAR!"
id.lproj/liar.m4a  → "Kamu BOHONG!"
```
`Bundle.main.url(forResource: "liar", ...)` auto-returns the current-language clip — code
stays ONE line, no `if language ==` branch. String Catalog (Part C) drives text, `.lproj`
drives audio, both off the same locale → change language, both switch together.
Cost: 4 bands × 2 languages = 8 clips. See the EN/ID lines in the band table above.

**NOT the accessibility feature** — this is a sound effect. VoiceOver (Part D) is separate
and still needed. Do after views frozen (touches result view; batch with B1 haptic).

---

## Part G — Apple Watch HR (v2 expansion)

Optional upgrade: if the player has a paired Watch, read live HR from it instead of
camera PPG. This is v2 — do AFTER the iPhone app is finished/shipping.

Already anticipated by the architecture: `HeartRateSource` protocol (Interfaces.swift).
A Watch HR source is just another conformer — swaps in with zero rewrite elsewhere.
Also matches STRUCTURE.md's planned `Shared/` for iOS+Watch code sharing.

### "How to pair?" — no custom pairing needed
The Watch is ALREADY paired to its iPhone at OS level (Apple's Watch app). Your app does
NOT build pairing UI. It just:
1. **Add a watchOS target** to the Xcode project. Give shared model files
   (`Models.swift`, etc.) membership in BOTH targets (see CLAUDE.md note).
2. **`WCSession`** (WatchConnectivity) — auto-connects to the paired Watch, no pairing flow.
3. **HR** = HealthKit `HKWorkoutSession` on the Watch (starting a workout unlocks live,
   high-frequency heart rate) → stream BPM to iPhone via `WCSession.sendMessage`.

### User option
Detect: `WCSession.default.isPaired` && `isWatchAppInstalled`. If both true → offer
"Use Apple Watch for heart rate". Else → fall back to camera PPG (`RealHeartRate`).

### Why it's better (fixes a known gotcha)
Watch reads HR **DURING** the answer (live), not 8s after on the loading screen like
camera PPG. Kills the "HR captured post-stress" shortcut (CLAUDE.md gotcha). No finger-on-
camera needed either.

### Cost
Medium-large: new watchOS target + HealthKit entitlement + `WCSession` both sides + a
minimal Watch UI. New `WatchHeartRate: HeartRateSource` conformer on the phone side reads
the streamed value. Requires a real Watch to test. v2 — post-iPhone-ship.

---

## Part H — AirPlay to TV (v2, mentor feedback)

Mentor idea: play from the living room with family — the game on the big screen.
v2, after the iPhone app is solid.

### The right shape: TV = shared big screen, phones = private controllers
NOT plain mirroring (that just copies one phone). Instead a dedicated **external-display
view**: the TV shows the SHARED state (whose turn, the big sus-meter reveal, running
scoreboard, "entertainment only" disclaimer); each phone stays a private controller
(your role, push-to-talk, your code). This is the party-game magic the mentor means.

### How (iOS external display)
- Detect an external screen: `UIScreen.didConnectNotification` / scene-based external
  display (`UIWindowScene` with the `.external` session role, iOS 16+).
- Render a second, TV-optimized SwiftUI view on that screen (big fonts, landscape).
- The **host's phone drives it** — it already holds full room state (turns, results,
  players). Host mirrors "the shared view" to the TV; its own screen keeps host controls.
- Works over AirPlay (to Apple TV / AirPlay-capable TV) or a Lightning/USB-C HDMI adapter.

### Fits the architecture
UI reads `GameViewModel`; the TV view is just ANOTHER SwiftUI view reading the same vm —
no logic changes, pure presentation. Slots in behind the existing `@Observable` state.

### Cost
Medium: external-scene plumbing + one TV layout. Needs an Apple TV / adapter to test.
Pairs well with Part A4 (scoreboard) — the TV is where a running scoreboard shines.

---

## Sequencing (all after Marleen/Agung layout push merges)
1. Identity-flow wiring (Pafras's owned task) — unblocks everything.
2. A1 + A3 (tiny logic, safe now).
3. B1 + B2 (haptics, batch with result/asking view edits).
4. A2 (reweight) after a playtest.
5. A4 scoreboard + B3/B4 (polish) last.
6. Part C localization — AFTER views frozen (else re-localize churn). Good beginner task.
7. Part D accessibility (VoiceOver on result) — REQUIRED, after views frozen.
8. Part E result voice — batch with B1 haptic on result view. Pafras records 8 clips.
9. Part F 4-band verdict — SusBand redesign (own files, tests survive).
10. Part G Apple Watch HR — v2, AFTER iPhone app finished/shipping.
