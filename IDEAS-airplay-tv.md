# IDEAS — AirPlay to TV (raw brainstorm)

Raw brainstorm from mentor feedback (2026-07-06): "play from the living room with
family on the big screen." NOT committed to — a pool of ideas to pull from in v2.
Structured plan lives in PLAN-logic-haptics.md Part H.

## Feasible?
Yes. iOS external-display API is real + documented (`UIScreen` / scene-based external
display, `UISceneSession` `.external` role, iOS 16+). No logic change — a TV view just
reads the same `@Observable GameViewModel`.

## Two modes
1. Mirror (lazy) — AirPlay screen mirroring, zero code, copies one phone. Boring + leaks
   private UI.
2. Second-screen (the good one) — app renders a SEPARATE TV view; phones stay private
   controllers. This is the mentor's vision.

## TV-screen content ideas
- Big sus-meter reveal — needle swinging Truth/Hmm/Liar on the 60-inch
- Whose-turn spotlight — big avatar + "BUDI is answering…"
- The question shown large so the room reads along
- Live scoreboard — running "biggest liar" leaderboard (ties to Part A4)
- Roulette role-reveal on the TV = slot-machine drama for the whole room
- Countdown / "judge is thinking…" suspense screen
- Recorded voice verdict (Part E) booms from TV speakers — "YOU'RE A LIAR!"
- End-of-game winner crown / "most sus of the night"

## Interaction angles
- TV = passive display; ALL input on phones (no Apple TV remote)
- Host phone = the "director" (drives TV, taps Start/Next)
- QR code on TV → new players scan to join the room (slick onboarding)

## Unknowns / risks
- Which phone drives the TV if host changes? → host owns it; on host-leave, TV view ends
- Landscape TV layout = a whole second design pass (Satria)
- Needs Apple TV / HDMI adapter to test — no Simulator path
- AirPlay latency (~100-300ms) — fine for reveals, avoid for tight timing
- Audio routing: TV speakers vs phone — decide per screen

## Effort
Medium. External-scene plumbing = small. The WORK = designing + building the TV layouts
(new landscape views, big type). No logic change.
