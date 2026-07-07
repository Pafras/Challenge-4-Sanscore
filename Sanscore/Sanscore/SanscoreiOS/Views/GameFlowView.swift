// GameFlowView.swift
// ROOT screen router. Reads GameViewModel.state and switches to the right
// screen. Computes nothing itself — all math + LLM stay in GameViewModel/
// SusEngine. Each screen now lives in its OWN file (see below) so the team can
// work in parallel without merge conflicts:
//
//   HomePageView.swift      RoomSetupView          (Marleen)
//   JoinRoomView.swift      JoinRoomView           (Marleen)
//   TakePictureView.swift   EditProfileView        (Agung)
//   SwipeToEnterView.swift  SwipeToEnterView (new)  (Agung)
//   GameRoomView.swift      RoomLobbyView + bubbles (Agung)
//   RoundViews.swift        gameplay screens        (Pafras)
//
// OWNER: Pafras (iOS). Only edit THIS file to change the state switch.
//
// RULE: a top-level `private struct` is only visible inside its own file. The
// views this switch calls live in other files now, so they are module-internal
// (no `private`). Helpers used inside a single file keep `private`.

import SwiftUI
import Combine
#if os(iOS)
import MultipeerConnectivity
#endif

struct GameFlowView: View {
    @State private var vm = GameViewModel()   // all mocks by default

    var body: some View {
        ZStack(alignment: .top) {
        VStack {
            switch vm.state {
            case .idle:
                RoomSetupView(vm: vm)
            case .nameEntry:
                #if os(iOS)
                NameEntryView(vm: vm)
                #else
                Color.clear.onAppear { vm.finishNameEntry("") }
                #endif
            case .identity:
                #if os(iOS)
                // Take photo (onCapture -> avatar) then swipe down (onEnter ->
                // lobby). Marleen's morphing identity screen, wired into the flow.
                IdentityCameraView(name: vm.playerName,
                                   onCapture: { img, colorIndex in vm.setMyAvatar(img, colorIndex: colorIndex) },
                                   onEnter: { vm.enterLobby() },
                                   onClose: { vm.cancelIdentity() })
                #else
                Color.clear.onAppear { vm.enterLobby() }
                #endif
            case .calibrating:
                // Figma sequence: LETS CALIBRATE -> put-finger warning ->
                // MEASURING HEART RATE (live BPM). Auto-advances in the vm.
                switch vm.calibrationPhase {
                case .instruction: LetsCalibrateView()
                case .warning:     WarningView()
                case .measuring:   MeasuringHeartRateView(bpm: vm.liveBPM)
                }
            case .syncing:
                // Barrier: this device is done calibrating, waiting for the rest
                // so the reveal starts on every phone at once. Usually a blink on
                // later rounds; a couple seconds on round 1 (slowest calibrator).
                SyncingView()
            case .roomLobby:
                RoomLobbyView(vm: vm)
            case .roleReveal:
                #if os(iOS)
                // Figma flow: a title card first — "LET'S BEGIN" on the first
                // round of a session, "WHO'S NEXT" on later rounds — then the
                // "picking roles" bubbles float + breathe while the host assigns.
                RoleRevealIntro(firstRound: !vm.hasPlayedARound) {
                    PickingRolesView(players: vm.lobbyPlayers, avatars: vm.avatars,
                                     displayNames: vm.displayNames, colorIndex: vm.avatarColorIndex)
                }
                #else
                RoleRevealView()
                #endif
            case .roleResult:
                // Roulette landed -> Agung's per-role reveal screen. Role is
                // decided in applyTurn before the roulette starts.
                switch vm.myRole {
                case .asker:     RoleInterrogatorView()
                case .answerer:  RoleSuspectView()
                case .spectator: RoleSpectatorView()
                }
            case .asking:
                // Interrogator's hold-to-question mic (Agung's Figma screen).
                InterrogatorHoldToQuestionView(onPress: { vm.askerPressed() },
                                               onRelease: { vm.askerReleased() })
            case .fingerCheck:
                // "PUT FINGER ON CAMERA PLZZZ" — live camera bg (torch on), so
                // the suspect lines their finger up before the answer starts.
                WarningView()
            case .answering:
                // Suspect's hold-to-answer mic. bpm is the LIVE rolling PPG
                // readout (capture runs during the answer); "--" until enough
                // signal. isEnabled defaults true: we only reach .answering
                // once the asker has released.
                SuspectHoldToAnswerView(bpm: vm.liveBPM,
                                        onPress: { vm.answererPressed() },
                                        onRelease: { vm.answererReleased() })
            case .spectating:
                // Spectator stays on the "you're the spectator" screen (not the
                // old "watching this round" waiting view).
                ZStack {
                    RoleSpectatorView()
                    #if DEBUG
                    VStack {
                        Spacer()
                        Button("Back") { vm.spectatorToLobby() }
                            .buttonStyle(.borderedProminent)
                            .padding(.bottom, 32)
                    }
                    #endif
                }
            case .waitingForResult:
                WaitingForResultView { vm.backToStart() }
            case .loading:
                LoadingView()
            case .calculating:
                CalculatingView(targetScore: vm.lastResult?.score)
            case .result:
                if let result = vm.lastResult {
                    ResultView(result: result,
                               canAdvance: vm.canAdvance) { vm.nextRound() }
                }
            }
        }
        .animation(.default, value: vm.state)

        // Toast layer — a sibling in the ZStack (not an overlay on the screen
        // switch) so it always floats ON TOP of every game screen, even the
        // full-bleed camera/background ones. High zIndex keeps it above any
        // transitioning view underneath.
        if let toast = vm.toast {
            SusToastView(toast: toast) { vm.dismissToast() }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
        }
        }
        .animation(.default, value: vm.toast)
    }
}

//MARK: - Role-reveal intro card

#if os(iOS)
// Plays a full-screen title card for ~1.3s, then crossfades to its content
// (the picking-roles bubbles). LET'S BEGIN on the first round of a session,
// WHO'S NEXT after — driven by vm.hasPlayedARound, set per-device when a
// result lands, so every phone picks right without an extra network message.
private struct RoleRevealIntro<Content: View>: View {
    let firstRound: Bool
    @ViewBuilder let content: Content
    @State private var showIntro = true

    var body: some View {
        ZStack {
            if showIntro {
                (firstRound ? AnyView(LetsBeginView()) : AnyView(WhosNextView()))
                    .transition(.opacity)
            } else {
                content.transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showIntro)
        .task {
            try? await Task.sleep(for: .seconds(1.3))
            showIntro = false
        }
    }
}
#endif

//MARK: - Shared background

// Reusable checkered overlay. Module-internal so any screen file can use it.
struct CheckeredBackground: View {
    let tileSize: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / tileSize))
            let cols = Int(ceil(size.width / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    if (row + col).isMultiple(of: 2) {
                        let rect = CGRect(x: CGFloat(col) * tileSize,
                                          y: CGFloat(row) * tileSize,
                                          width: tileSize, height: tileSize)
                        context.fill(Path(rect), with: .color(.white.opacity(0.08)))
                    }
                }
            }
        }
    }
}

#Preview {
    GameFlowView()
}
