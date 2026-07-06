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
                CalibratingView(prompt: vm.calibrationPrompt,
                                step: vm.calibrationStep + 1,
                                total: vm.calibrationPrompts.count,
                                onPress: { vm.calibrationPressed() },
                                onRelease: { vm.calibrationReleased() })
            case .roomLobby:
                RoomLobbyView(vm: vm)
            case .roleReveal:
                #if os(iOS)
                // "Picking roles" — lobby bubbles float + breathe while the host
                // assigns this round. (Replaces the old colour roulette.)
                PickingRolesView(players: vm.room.players, avatars: vm.avatars,
                                 displayNames: vm.displayNames, colorIndex: vm.avatarColorIndex)
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
                AskingView(onPress: { vm.askerPressed() },
                           onRelease: { vm.askerReleased() })
            case .answering:
                AnsweringView(onPress: { vm.answererPressed() },
                              onRelease: { vm.answererReleased() })
            case .spectating:
                // Spectator stays on the "you're the spectator" screen (not the
                // old "watching this round" waiting view).
                ZStack {
                    RoleSpectatorView()
                    #if DEBUG
                    VStack {
                        Spacer()
                        Button("Back") { vm.backToStart() }
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
                CalculatingView()
            case .result:
                if let result = vm.lastResult {
                    ResultView(result: result,
                               canAdvance: vm.canAdvance) { vm.nextRound() }
                }
            }
        }
        .animation(.default, value: vm.state)
        .overlay(alignment: .top) {
            if let notice = vm.leftNotice {
                Label(notice, systemImage: "person.fill.xmark")
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: vm.leftNotice)
    }
}

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
