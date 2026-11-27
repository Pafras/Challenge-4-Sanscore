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

IPHONE ONLY
This version is iPhone-only. It does not include an Apple Watch app, does not
use HealthKit and never asks for Health permission. Heart rate is read only
from the rear camera as described above.

APPLE INTELLIGENCE IS OPTIONAL (ON-DEVICE AI)
On iPhones with Apple Intelligence, the app uses Apple's on-device Foundation
Models framework. A short on-device session reads the transcribed text of the
answer, rates how it is phrased (evasive, vague, rambling, inconsistent) and
writes the one-line verdict. That rating is blended into the score with a 25%
weight; the four measured signals (heart rate, response time, speech rate and
mid-answer pauses) make up the rest. It runs entirely on the device, so no
answer text or audio is sent anywhere. On every other supported iPhone (the
minimum is iOS 18) the score uses the four measured signals only and the
verdict line is picked from a built-in list, so the game still works on an
older review device. Scores can differ slightly between the two.

LANGUAGE
The interface is available in English and Indonesian. Speech recognition is
English-only by design, and the app tells players to ask and answer in English.

CONTACT
[your name] — [your email]
