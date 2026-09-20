# App Review Notes (paste into App Store Connect)

Draft for the "Notes" field of App Review Information. Keep it under 4000
characters. Update the bracketed bits before submitting.

---

Sanscore ("SussMeter") is a face-to-face party game for groups. One player
answers a question out loud and the app shows a playful "sus meter". It is
ENTERTAINMENT ONLY and is not a lie detector; the app says so on screen. No
result is presented as truth, diagnosis, or fact about a person.

TESTING WITH ONE DEVICE
The game is designed for several phones in the same room, but it is fully
playable on a single device, so no second device is needed to review it:
1. Tap CREATE.
2. Type any name, tap DONE.
3. Take a photo (or tap the camera badge and skip), then tap JOIN.
4. You are in the room. Tap START.
5. Calibration: hold a fingertip over the REAR camera lens for ~8 seconds
   while it reads a resting heart rate. The torch turns on — this is normal.
6. You are given a role. Hold anywhere on the screen to speak the question,
   release, then hold again to speak the answer, and release.
7. The result screen shows the score and a verdict line.
On one device the same phone plays both roles in turn, so the whole loop can
be reviewed alone.

PERMISSIONS AND WHY
- Microphone + Speech Recognition: the spoken answer is transcribed so the
  game can measure speaking pace and pauses. Recognition is on-device
  (requiresOnDeviceRecognition = true). Audio is never uploaded or stored.
- Camera: measures a pulse from a fingertip pressed on the rear lens
  (photoplethysmography, the same idea as a fitness app's camera heart rate),
  and optionally takes a small lobby avatar photo. No video is recorded or
  saved.
- Local Network: finds other phones in the same room over
  MultipeerConnectivity. There is no server and no internet connection. If
  this permission is denied, single-device play above still works; only
  joining other phones is unavailable.
- Photo Library: only if the player picks an existing photo as their avatar.

NO ACCOUNT, NO SERVER, NO DATA COLLECTION
There is no sign-in, no account, and no backend. Everything runs on the
device. Between phones in the same room, only a player's chosen name, a small
avatar image, the question text and the round result are sent, and only over
the local network. Nothing is collected by us — the privacy nutrition labels
are set to Data Not Collected. Heart rate and voice never leave the phone.

HEALTHKIT
The app does NOT use HealthKit in this version and never asks for Health
permission. The HealthKit purpose strings are present only because an Apple
Watch companion file still links HealthKit.framework; without them the upload
is rejected with ITMS-90683. The app has no HealthKit entitlement and makes no
Health queries. The Apple Watch app is not included in this version.

APPLE INTELLIGENCE IS OPTIONAL
On iPhones with Apple Intelligence, an on-device Foundation Models session
writes the one-line verdict text. On every other supported iPhone (the minimum
is iOS 18) the app picks a line from a built-in list instead. The score itself
never depends on Apple Intelligence, so the game behaves the same on an older
review device.

LANGUAGE
The interface is available in English and Indonesian. Speech recognition is
English-only by design, and the app tells players to ask and answer in English.

CONTACT
[your name] — [your email]
