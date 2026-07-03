# HANDOFF-UI.md — UI slicing (Agung + Marleen)

Read this before you touch the UI. Raw download:
`https://raw.githubusercontent.com/Pafras/Challenge-4-Sanscore/dev/HANDOFF-UI.md`

## What happened

`GameFlowView.swift` was ONE 769-line file with every screen inside. If two
people edit one file → git merge conflicts. So it's now sliced into **one file
per screen**. Each person owns separate files → you never touch the same file →
**zero conflicts**.

## Who owns what

| File | Screen (Figma) | Owner |
|------|----------------|-------|
| `HomePageView.swift` | Homepage (SUSS + JOIN/Create) | **Agung** |
| `JoinRoomView.swift` | Join Room (enter room code numpad) | **Agung** |
| `TakePictureView.swift` | Take a Picture (make your identity) | **Marleen** |
| `SwipeToEnterView.swift` | Slide to Enter ("you're all set") | **Marleen** |
| `GameRoomView.swift` | Game Room (bubbles, waiting, START) | **Agung** |
| `RoundViews.swift` | gameplay (Let's Begin / Who's Next / result) | Pafras |
| `GameFlowView.swift` | root state switch | Pafras |

All files: `Sanscore/Sanscore/SanscoreiOS/Views/`

## ✅ DO

- **Edit only YOUR files** (the table above).
- **Work on your own branch**: `git checkout dev && git pull && git checkout -b marleen/photo`
  (Marleen owns `TakePictureView` + `SwipeToEnterView`; Agung owns `HomePageView`
  + `JoinRoomView` + `GameRoomView`.)
- **`git pull` `dev` before you start** each session — stay current.
- **Match Figma** — fonts, colors, spacing, images. Layout only.
- **Use `#Preview`** (bottom of each file) — Xcode canvas renders YOUR screen
  live, no need to play the game to reach it.
- **Call existing `vm` methods** for buttons. Copy the exact call already in the
  code, e.g. `Button("CREATE") { vm.createRoom() }`, `{ vm.start() }`,
  `{ vm.startBrowsing() }`.
- **Build before you push** — Xcode `Cmd+B` must be green. A broken push blocks
  everyone's build.
- **Small commits**, one PR per person → merge to `dev`.
- **Stuck on anything logic? Ask Pafras.**

## ❌ DON'T

- **DON'T touch other people's files** — not even a "small fix". That's how
  conflicts happen.
- **DON'T edit** `GameViewModel.swift`, `SusEngine.swift`, `Models.swift`, or
  the `GameState` enum. That's Pafras. Logic ≠ UI.
- **DON'T invent new `vm` methods.** Only call ones that already exist. Need a
  new action? Ask Pafras to add it.
- **DON'T compute in the View** — no math, no scoring, no "if this then score".
  The View shows; `vm` thinks.
- **DON'T change the screen order / flow** — that's the `GameState` switch =
  Pafras.
- **DON'T rename / move / delete** structs you didn't create.
- **DON'T push code that won't build.**
- **DON'T commit signing** (`Config/Local.xcconfig`) — it's git-ignored, leave it.

## One-line rule

> **Your file. Layout only. Call `vm`, never edit `vm`. Build green before push.**

## Notes

- **Struct names kept the same** so the root switch keeps working — e.g.
  `HomePageView.swift` contains `struct RoomSetupView`. Don't rename them.
- **`TakePicture` + `SwipeToEnter`** in Figma come BEFORE the room; today the
  code shows the photo as a lobby sheet. Re-ordering the flow = new `GameState` +
  `vm` method = **Pafras's job**. You build the layout; Pafras wires the order.
- `SwipeToEnterView` is a **new stub** — style it; Pafras wires the swipe to a
  real action later.
