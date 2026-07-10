# Sanscore — Project Report

**Apple Developer Academy · Challenge 4**

---

## What it is

**Sanscore** (a.k.a. *SussMeter*) is a **party game for your phone**. One player
answers a question out loud, and the app gives them a fun "how suspicious was that?"
verdict — from *Very Truth* to *Very Sus*.

> It's a game for laughs, **not a real lie detector** — and the app says so.

---

## How you play

4–5 friends in a room, each on their own iPhone, joined to the same game with a
4-digit code. Each round:

- One person **asks** a question.
- One person **answers** out loud while holding their phone.
- Everyone else **watches** the verdict land.

Then roles rotate. Fast, silly, social.

---

## How the app "reads" you

While you answer, the app quietly looks at **four things about *how* you answered**
— never whether you're actually telling the truth. Each is compared against *your
own normal* (measured in a quick warm-up), so it judges you against yourself.

- **Heart rate** — did your pulse jump? (read through the back camera + flash)
- **Response time** — did you freeze before answering?
- **Speaking speed** — did you rush or stall?
- **How you phrased it** — was the answer dodgy or vague? (judged by an AI on the
  phone)

These blend into one score that picks your verdict.

---

## Why it's private

**Nothing you say or measure ever leaves your phone.** No internet, no server, no
accounts — everything runs on the device. The phones talk to each other directly,
and the *only* thing shared is the final result: your name, score, and verdict.

---

## How it's built

The game's "brain" is kept separate from the sensors and the screens — like Lego.
So the team can test the whole thing with fake sensors on a simulator, then snap in
the real camera, microphone, and AI on a real phone with no rewrites. It also lets
designers and coders work at the same time without clashing.

Built in **SwiftUI** for iPhone, using Apple's on-device AI and a direct
phone-to-phone connection for the local multiplayer.

---

## Honest trade-offs

It's a party game, so a few things are intentionally "good enough":

- Heart rate is read *just after* the answer, not during it.
- The pulse reading wobbles a little — unnoticeable while playing.
- It assumes everyone's on a recent iPhone with Apple's on-device AI.

---

## Requirements & team

- **Languages:** English + Indonesian, switchable in-app.
- **Accessibility:** VoiceOver reads the result aloud *(in progress)*.

| Member | Owns |
|---|---|
| **Pafras** (lead) | Scoring brain, glue logic, sensors (camera, mic, connection) |
| **Agung** | AI answer-reading + screens |
| **Marleen** | Screens + sound and music |
| **Satria** | Visual design |

---

## What's next

Read heart rate *during* the answer · a running scoreboard · Apple Watch heart rate
· play it on a TV via AirPlay.
