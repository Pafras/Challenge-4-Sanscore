# TEST — identity-flow wiring (Agung + Marleen screens + Pafras wiring)

Checklist for the latest push. Tick each. Camera/mic/LLM = REAL PHONE only;
Simulator uses mocks (click buttons, no real camera).

Legend: [S]=works on Simulator · [P]=needs real iPhone · [2]=needs 2 devices

---

## 1. Home screen (Agung — HomePageView / RoomSetupView)
- [ ] [S] SUSS logo + JOIN + CREATE show, pink bg
- [ ] [S] CREATE → goes to identity/photo screen (NOT straight to lobby)
- [ ] [S] JOIN → browse list opens
- [ ] [S] room-closed alert shows here after a host leaves

## 2. Identity screen (Marleen — IdentityCameraView)
- [ ] [P] live front camera shows, background removed
- [ ] [P] swipe colour carousel → background colour changes, snaps
- [ ] [P] shutter → morphs to "YOU'RE ALL SET" in place (no page jump)
- [ ] [P] retake badge → back to camera, retake works
- [ ] [S/P] swipe DOWN → enters lobby (onEnter wired)
- [ ] [S] back button (top-left) → returns HOME, room NOT created

## 3. Join flow (Agung — JoinRoomView / JoinRoomView2)
- [ ] [2] host in lobby → 2nd device JOIN sees the room (random name)
- [ ] [S] tap room → code card slides up
- [ ] [S] tap number buttons (mouse-click, NOT Mac keyboard) → digits fill
- [ ] [2] correct code → identity screen → swipe → lands in SAME lobby
- [ ] [2] wrong code → host rejects, no join
- [ ] [S] back from join → home

## 4. Game room / lobby (Marleen + Agung — GameRoomView, PlayerBubblesPhysics)
- [ ] [2] all players show as bubbles, YOUR photo on your bubble
- [ ] [P] bubbles drift / react to gyroscope tilt
- [ ] [2] joiner's photo appears on host screen (avatar broadcast on connect)
- [ ] [2] random player names show (not "iPhone")
- [ ] [S] room name + 4-digit code visible

## 5. Avatar / identity edge cases (Pafras wiring)
- [ ] [S] swipe to enter WITHOUT taking a photo → lobby, initials fallback, NO crash
- [ ] [P] retake → the LATEST photo is the one that enters the lobby
- [ ] [S] lobby "edit photo" (tap own bubble) → old sheet still works, doesn't break

## 6. Ghost-room / teardown (the bugs just fixed)
- [ ] [S] CREATE → photo → back → other device's JOIN list has NO room
- [ ] [2] host lobby → leave/back → room clears from other device (allow ~5-10s MC lag)
- [ ] [2] two hosts at once → two distinct room names, no collision

## 7. Full round end-to-end (didn't break downstream)
- [ ] [2] lobby → host START → role reveal (roulette)
- [ ] [2] asker asks (hold to talk) → answerer answers → result shows on all
- [ ] [2] next round → roles rotate
- [ ] [S] 2-Simulator run does all of this with mocks (no hardware)

---

## Priority (do first)
1. **§7 [2]** — full round end-to-end = the real proof nothing broke.
2. **§3 [2]** join → identity → same lobby = the wiring's hardest path.
3. **§5 no-photo** — crash guard.
4. **§6 ghost-room** — the fix we just shipped.

Any fail → note the §number + what happened, hand to Pafras/Claude.
