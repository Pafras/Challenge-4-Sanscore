# Sanscore

Apple Developer Academy — Challenge 4.

**Sanscore** is an iOS + watchOS party game: a "truth or lie" group game where one
player answers a question out loud, the app measures them, and a **sus meter** shows a
verdict (Truth / Hmm / Liar). It is **entertainment only — not a real lie detector.**

---

# Sanscore — Tech Report

## 1. Present Your Team

- **Pafras** (lead) — SusEngine, ViewModel, integration, and all async/hardware
  modules (speech capture, camera heart-rate, room networking). The strongest coder;
  owns the parts that touch sensors and the network.
- **Agung** — the LLM answer-structure analyzer (`StructureAnalyzer`): fields, prompt,
  and weights tuned and live on device. Then front-end UI slicing.
- **Marleen** — front-end UI slicing and the identity/photo screens.
- **Satria** — design only (Figma), no code.

Beginners (Agung, Marleen) get isolated, spec'd, testable tasks behind protocols; the
lead owns the async/hardware/integration surface.

---

## 2. Starting Assumption

*(Our honest guess, before any research.)*

We assumed a convincing lie detector needed a **trained machine-learning model** — feed
it sensor data, let it learn what "lying" looks like. The plan in our heads was CoreML
with some training set of truthful vs. deceptive answers. We also assumed we'd need a
**backend server** to coordinate players and run the heavy inference, and that an LLM
would need to "listen" to the audio to judge the answer.

---

## 3. The Exploration Log

*(Our actual process, not the conclusion.)*

1. **Framed it as a game, not a tool.** The first real decision was to make Sanscore
   *entertainment only*. This sidesteps medical/accuracy claims and keeps App Store
   review happy — and it changes every downstream technical requirement (we no longer
   need to be "correct," only fun and consistent).
2. **Broke deception into 4 measurable signals**, each normalized 0–1 as deviation from
   the player's own calibration **baseline**, then fused by a **weighted sum**:

   ```
   susScore = 0.3·hr + 0.2·responseTime + 0.2·speechRate + 0.3·structure
   ```

   | Signal | Source | Judge |
   |--------|--------|-------|
   | Heart rate | camera PPG (finger + torch) | math |
   | Response time | timer: asker-release → answerer-press | math |
   | Speech rate | words ÷ duration from `SFSpeechRecognizer` | math |
   | Answer structure (evasive/vague) | the transcript text | **Foundation Models LLM** |

   Rule that fell out: **LLM judges meaning; math judges everything else.**
3. **Built protocol-driven from day one** so logic runs on mocks in Simulator and real
   modules swap in with zero rewrite: `signals (protocols) → SusEngine (fuse) →
   GameViewModel → SwiftUI`. Protocols: `HeartRateSource`, `SpeechCapturing`,
   `StructureAnalyzing`, each with a mock + a real iOS implementation.
4. **Tested the brain first.** `SusEngine` weighted-sum fusion got unit tests before any
   UI existed.
5. **Added a 3-question calibration** to set a per-player baseline (shows your BPM),
   because absolute HR is meaningless — deviation is the signal.
6. **Built real multiplayer over MultipeerConnectivity** — local rooms, 4-digit room
   code, turn-order sync, tested Simulator↔device. Only the `RoundResult` (name + score +
   verdict) crosses the network.
7. **Swapped mocks for real sensors** one at a time: speech (`SFSpeechRecognizer`),
   camera PPG heart rate, then the on-device Foundation Models LLM.
8. **Sliced the one 769-line `GameFlowView.swift`** into one file per screen so two
   beginners could build UI without constant merge conflicts.

---

## 4. What We Tried and Dropped

- **CoreML / a trained model — dropped.** We had **no training data** and no way to label
  "truthful" vs. "deceptive" answers. A weighted sum of four normalized signals plus
  **one** LLM call covers the same ground with zero training and full explainability. Cut.
- **A backend server — dropped.** Rooms are **local** (MultipeerConnectivity), same-room
  only. No backend, no internet. This was originally a scaling assumption; it became a
  **privacy feature** — voice and heart-rate never leave the phone.
- **LLM listens to audio — dropped.** The LLM reads **text only**: `SFSpeechRecognizer`
  transcribes audio → `String` → LLM. The same transcript feeds both the speech-rate math
  and the LLM, so we transcribe once and use it twice.
- **`MCBrowserViewController` (Apple's stock room browser) — dropped** for a custom
  nearby-rooms list, so the host's chosen name shows in the list instead of the raw device
  name, and so we could gate joins on a 4-digit code.

---

## 5. Real Limitations Hit

- **Heart rate is captured ~8s AFTER the answer**, not during. The current build runs a
  fresh camera-PPG capture on the loading screen (with a countdown ring) that needs a
  finger on the back camera + torch. So HR is read *post-stress*, not at the moment of the
  answer. Real fix later: capture HR *during* the answer.
- **Camera PPG is noisy: ±10–15 BPM jitter.** We use a moving-average detrend +
  zero-crossing pulse count instead of a proper bandpass + FFT. Accepted — it's a party
  game, not a clinic.
- **Speech finalization is a shortcut:** a 300 ms wait for the final transcript instead of
  awaiting `SFSpeechRecognizer`'s `isFinal`.
- **MultipeerConnectivity Simulator-to-Simulator discovery is flaky.** Workaround: 1
  Simulator + 1 real iPhone when a room won't appear. `NSBonjourServices` in `Info.plist`
  is required for discovery on real devices.
- **Foundation Models needs an iOS 26 Apple-Intelligence device to actually run.** It's
  gated `#if canImport(FoundationModels)` + `if #available(iOS 26)`, with a mock otherwise
  — so it can't be tested in Simulator at all.
- **What AI couldn't help with:** none of the sensor timing, the PPG signal noise, or the
  peer-to-peer discovery flakiness are things a model solves — they're
  physical/hardware/networking realities we had to design around.

---

## 6. The Revised Decision

*(What changed since Section 1, and why.)*

- **No CoreML.** The trained-model assumption was wrong for our constraints — no data, no
  labels, no need. A **weighted sum + one LLM call** replaced the entire ML premise.
- **No server.** The backend assumption inverted into a design principle: **on-device
  only, privacy by design.** Rooms are local; only name + score + verdict travel between
  phones.
- **The LLM reads text, not audio**, and does one job — judging answer *structure*
  (evasiveness / vagueness). Everything else is arithmetic.
- **The "not a lie detector" framing became the foundation**, not a disclaimer. It's what
  let us drop accuracy requirements and ship a fun, consistent, explainable game.

---

## App / Game Addendum

- **Frameworks:** SwiftUI (UI), `SFSpeechRecognizer` (speech-to-text), AVFoundation camera
  + torch (PPG heart rate), **Foundation Models** (on-device LLM, iOS 26+),
  **MultipeerConnectivity** (local rooms). No third-party dependencies. No CoreML.
- **Privacy:** on-device only. Voice and heart-rate never leave the phone. No server, no
  internet. Only the `RoundResult` (name + score + verdict) crosses the local network. Mic
  / speech / camera / local-network / photo usage strings in `Info.plist`.
- **Mechanics:** face-to-face group play (4–5 people), everyone on their own iPhone joining
  a local room. Roles rotate round-robin (asker / answerer / spectator). Flow: create/join
  room → lobby → role reveal → the asker asks (push-to-talk) → the answerer answers
  (push-to-talk) → measure → sus meter. Push-to-talk = hold anywhere to talk, release to
  finish.
- **Player experience:** avatar bubbles drift in the lobby (photo or initials); tap your
  own to set a photo + name. A 3-question calibration personalizes the baseline (and shows
  your BPM). The sus meter delivers the payoff: Truth / Hmm / Liar — for laughs, not
  verdicts.
- **Target hardware:** iPhone 17 (all have Apple Intelligence for the LLM).
