# Sanscore

Apple Developer Academy — Challenge 4.

**Sanscore** (a.k.a. *SussMeter*) is a **party game for your phone**. One player
answers a question out loud, the app "reads" them, and a fun **sus meter** shows a
verdict — from *Very Truth* to *Very Sus*. It's **entertainment only — not a real
lie detector**, and the app says so.

---

# Sanscore — Tech Report

## 1. Present Your Team

- **Pafras** (lead) — the scoring "brain," the glue logic, and the tricky sensor
  work (camera, microphone, phone-to-phone connection).
- **Agung** — the AI that reads *how* an answer is phrased, plus front-end screens.
- **Marleen** — front-end screens and all the sound and music.
- **Satria** — visual design (Figma).

The lead handles the hard sensor/logic parts; the rest build the screens behind
clean hand-offs so everyone can work at once without clashing.

---

## 2. Starting Assumption

*(Our honest guess, before any research.)*

We assumed a believable lie detector would need a real **heart-rate sensor**, a
**server** to connect players and do the heavy thinking, and an **AI that listens
to your voice** to judge the answer. We even considered passing around an Apple
Watch to read pulses.

---

## 3. The Exploration Log

*(What we actually did.)*

1. **Called it a game, not a tool.** Making it *entertainment only* was the first
   big call — it means we don't have to be *accurate*, only *fun and consistent*.
2. **Split "suspicious" into four things we can measure**, each compared to the
   player's own normal, then blended into one score:
   - **Heart rate** (did your pulse jump?) — read through the back camera + flash
   - **Response time** (did you freeze?)
   - **Speaking speed** (rushing or stalling?)
   - **How it's phrased** (dodgy or vague?) — judged by an on-phone AI

   The rule that emerged: **the AI judges wording; simple math judges everything
   else.**
3. **Built it like Lego** so the game runs on fake sensors during testing, then the
   real camera, mic, and AI snap in with no rewrites.
4. **Tested the scoring first**, before any screens existed.
5. **Added a quick warm-up** so the game learns each player's normal — because a
   raw heart rate means nothing; the *change* is what matters.
6. **Made real phone-to-phone multiplayer** — local rooms with a 4-digit code, no
   internet. Only the final result travels between phones.
7. **Swapped in the real sensors one at a time** — speech, then camera heart rate,
   then the on-phone AI.

---

## 4. What We Tried and Dropped

- **A trained AI model — dropped.** We had no data to teach it what "lying" looks
  like. Four simple measurements plus one AI call do the job with none of the
  hassle.
- **A server — dropped.** Rooms are local and phone-to-phone. This turned into a
  *privacy win*: your voice and heart rate never leave your phone.
- **AI listening to audio — dropped.** The AI reads the *text* of your answer, not
  the sound. We turn speech into text once and use it for both jobs.

---

## 5. Real Limitations Hit

- **Heart rate is read just *after* the answer, not during it** — simpler to build.
  Reading it live is the planned upgrade.
- **The pulse reading wobbles** by ~10–15 beats — unnoticeable in a party game.
- **The on-phone AI needs a recent iPhone** with Apple Intelligence, so it can't be
  tested on a plain simulator.
- **Some things AI can't fix for us** — sensor timing, camera-pulse noise, and
  flaky phone-to-phone discovery are physical realities we had to design around.

---

## 6. The Revised Decision

*(What changed, and why.)*

- **No trained model, no server.** Both assumptions were wrong for us — we replaced
  them with simple math + one AI call, all running on the phone.
- **On-device only became the point**, not a compromise: private by design.
- **The AI does one small job** — judging *how* an answer is phrased. Everything
  else is arithmetic.
- **"Not a lie detector" became the foundation**, not a disclaimer — it's what let
  us drop accuracy worries and just make it fun.

---

## App / Game Addendum

- **Built with:** SwiftUI, Apple's speech-to-text, the camera + flash for heart
  rate, Apple's on-phone AI, and a direct phone-to-phone connection. No outside
  services.
- **Privacy:** everything on-device; only your name, score, and verdict are shared
  with the other players.
- **How it plays:** 4–5 friends, each on their own iPhone, join one local room.
  Roles rotate — one asks, one answers, the rest watch — then the sus meter gives
  the verdict for everyone to react to.
- **Made for:** recent iPhones with Apple Intelligence.
