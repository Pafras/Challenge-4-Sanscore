// ProfileConfirmView.swift — repurposed as the identity-flow DEMO harness.
//
// The old standalone "You're all set" stub is superseded: Take-a-picture and
// Slide-to-enter are now ONE morphing screen (IdentityCameraView). This file
// now hosts a DEMO so Marleen can SEE the whole flow end-to-end in #Preview,
// with no teammate files touched:
//
//   identity morph  →  swipe down (photo drags out, shrinks, leaves screen)
//                    →  game room, the new player's photo drops in FROM THE TOP
//
// The demo game room is a throwaway MOCK. The REAL game room is Agung's
// GameRoomView (with the gyroscope bubbles). This is reference only — Agung +
// Pafras graft the transition + the from-top entry into the real flow later.
//
// OWNER: Marleen (demo) + Pafras (real wiring). See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)

/// Runnable demo of the full identity → room flow. Open the #Preview.
struct IdentityFlowDemo: View {
    private enum Phase { case identity, room }
    @State private var phase: Phase = .identity
    @State private var photo: UIImage?

    var body: some View {
        ZStack {
            switch phase {
            case .identity:
                IdentityCameraView(
                    onCapture: { p, _ in photo = p },
                    onEnter: { withAnimation(.easeInOut(duration: 0.4)) { phase = .room } },
                    onClose: {}
                )
            case .room:
                DemoGameRoom(photo: photo)
            }
        }
    }
}

/// Throwaway mock of the game room — only here to show the new player's photo
/// dropping in from the top. REAL room = Agung's GameRoomView.
private struct DemoGameRoom: View {
    var photo: UIImage?
    @State private var dropped = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()

            // Filler bubbles for context.
            Circle().fill(.blue).frame(width: 92, height: 92).offset(x: -110, y: -40)
            Circle().fill(.green).frame(width: 92, height: 92).offset(x: 96, y: 70)
            Circle().fill(.yellow).frame(width: 92, height: 92).offset(x: -70, y: 190)
            Circle().fill(.pink).frame(width: 92, height: 92).offset(x: 90, y: 240)

            VStack {
                Text("ROOM ALPHA\n0347")
                    .font(.system(size: 22, weight: .black)).fontWidth(.expanded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.5)))
                Spacer()
                Text("Waiting for host to start the game")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
            }
            .padding(.top, 60)

            // The new player's photo — flies in from ABOVE the screen.
            playerBubble
                .offset(y: dropped ? -90 : -800)
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                        dropped = true
                    }
                }
        }
    }

    private var playerBubble: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Circle().fill(Color(red: 1, green: 0.42, blue: 0.42))
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 5))
    }
}

/// Back-compat: the old stub name now just shows the morphing identity screen,
/// so any reference to ProfileConfirmView keeps compiling.
struct ProfileConfirmView: View {
    var onEnter: () -> Void = {}
    var body: some View {
        IdentityCameraView(onCapture: { _, _ in }, onEnter: onEnter, onClose: {})
    }
}

#Preview("Identity flow (demo)") {
    IdentityFlowDemo()
}
#Preview("Profile Confirm") {
    ProfileConfirmView()
}

#endif
