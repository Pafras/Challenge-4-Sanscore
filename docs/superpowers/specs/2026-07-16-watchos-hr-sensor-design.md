# watchOS HR Sensor — Design

Date: 2026-07-16
Owner: Pafras
Status: approved (scope A, screens 1–3)

## Goal

Add an Apple Watch app that measures the player's **real heart rate** during
their answer and streams it to their own iPhone. It drops in as a
`HeartRateSource`, replacing the camera-PPG finger-on-lens flow. Because the
answerer holds the phone, the watch measures HR **hands-free, during the
answer** — fixing both known HR gotchas (finger-on-lens + HR read 8s late).

Entertainment only. Not a medical device. (App framing unchanged.)

## Scope

**In:** watch as HR sensor; watch screens 1–3 (Waiting, Ready, Measuring);
iPhone-side `WatchHeartRate: HeartRateSource`; WatchConnectivity plumbing;
drop into `GameViewModel.init`.

**Out (YAGNI):** result-glance screen (4), not-your-turn screen (5), any
room/turn logic on the watch, HR during calibration, auto-fallback to camera.

## Architecture

1:1 native pairing — each player's watch talks ONLY to their own paired iPhone.
No MultipeerConnectivity on the watch; the watch never knows about rooms.

```
Watch (new SanscoreWatch target)          iPhone (existing app)
 HKWorkoutSession → live HR ~1/s          WatchHeartRate : HeartRateSource
 WCSession.sendMessage({bpm})  ─────────► stores latest BPM (liveBPM / finish)
 receive {cmd: start|stop}     ◄───────── sends start on .answering, stop on release
```

### iPhone side — `Shared/Services/WatchHeartRate.swift`

Conforms to the existing `HeartRateSource` protocol (already written to accept a
Watch source; the protocol's default live methods exist for exactly this).

- `startLiveCapture()`  → WCSession `sendMessage({cmd:"start"})`; reset buffer
- `liveBPM() -> Double?` → latest BPM received (drives on-screen readout)
- `finishLiveCapture() -> Double` → `sendMessage({cmd:"stop"})`; return last (or
  short trailing average) BPM
- `currentBPM()` → start → wait → finish (protocol default is fine, or explicit)
- Holds a `WCSessionDelegate` that receives `{bpm: Double}` and stores latest.
- **Fallback:** if no watch samples arrived (no watch / unreachable), return
  neutral `75` — same sentinel `RealHeartRate` already uses.

Wire in `GameViewModel.init`: on device, use `WatchHeartRate()` in place of
`RealHeartRate()`. (Keep `RealHeartRate` in the tree as the documented later
fallback.)

### Watch side — `SanscoreWatch/` (created by Xcode target wizard)

Small SwiftUI watch app, ~2–3 files:

- `SanscoreWatchApp.swift` — `@main`, shows one root view.
- `WatchConnector.swift` — `@Observable`; `WCSessionDelegate` +
  HealthKit. On `{cmd:"start"}` → start `HKWorkoutSession` +
  `HKLiveWorkoutBuilder`, subscribe to HR quantity, each sample →
  `sendMessage({bpm})`, drive `state = .measuring`, play `.start` haptic. On
  `{cmd:"stop"}` → end workout, `state = .ready`.
- `WatchRootView.swift` — switches on state:
  - **1 Waiting** — session not reachable: "Open Sanscore on iPhone"
  - **2 Ready** — reachable, idle: "Connected" + idle heart
  - **3 Measuring** — animated heart + live BPM (`Text("\(bpm)")`)

Watch state enum: `.waiting`, `.ready`, `.measuring`.

## HealthKit / entitlements

- Watch target needs the **HealthKit** capability + `NSHealthShareUsageDescription`
  (read heart rate) in the watch Info.plist.
- Live HR ~1Hz requires a running `HKWorkoutSession` (workout mode). Standard
  trick; logs a short "workout" to Health. `ponytail:` acceptable for a party
  game — note it in code.
- Request HealthKit authorization on first launch.

## Simulator support

Watch simulator has **no HR sensor**. Add a `#if targetEnvironment(simulator)`
path in `WatchConnector`: on start, emit a fake wandering BPM (~70–95) on a
timer instead of HealthKit, so the flow is demoable in the sim. Real HR needs a
real Apple Watch.

## Known ceilings (`ponytail:` in code)

- `HKWorkoutSession` just to read HR — accepted; upgrade path: none needed for a
  party game.
- No camera fallback if watch absent → neutral 75. Later: fall back to
  `RealHeartRate`.
- `sendMessage` needs both apps reachable; the workout session keeps the watch
  awake during a round, so it holds for face-to-face play.

## Constraint: target creation is manual

`project.pbxproj` must not be committed/edited by Claude (project rule). Adding a
watchOS **target** is a pbxproj change. So:

1. **Pafras** (Xcode): File → New → Target → **watchOS → App**, name
   **`SanscoreWatch`**, "Watch App for iOS App" paired to Sanscore. This writes
   the pbxproj, folder `SanscoreWatch/`, signing, and the synchronized root.
2. **Claude**: fills every `.swift` in `SanscoreWatch/` + adds
   `WatchHeartRate.swift` on the iOS side (both auto-join their targets via
   synchronized folders — no pbxproj edit).

## Success criteria

- Watch app builds and runs; shows Waiting → Ready as the phone connects.
- Entering `.answering` on the phone flips the watch to Measuring (haptic tap).
- iPhone's live BPM readout shows numbers coming from the watch.
- Release → watch returns to Ready; the round scores with the watch BPM.
- In the simulator, the fake-BPM path drives the same flow end-to-end.
