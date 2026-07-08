// SussConfirmDrawer.swift
// Bottom confirm drawer (Figma "Leave Room / End Game" sheets): pink homepage
// bg, grabber, blue stroked title, white message, CANCEL + confirm buttons.
// Used by the game room (CLOSE/LEAVE ROOM?); Pafras's END GAME? / LEAVE GAME?
// screens can reuse it as-is.
//
// Present inside `.sheet { }` — the system sheet gives the smooth slide/drag
// animation; this view sets its own detent/corner/background.
//
// OWNER: Marleen (design system).

import SwiftUI
#if os(iOS)

extension View {
    /// Extra dim behind a drawer sheet. The system sheet dim is quite light —
    /// design wants drawers darker. Attach to the PRESENTING view with the
    /// sheet's isPresented flag; it fades in/out with the sheet and stacks on
    /// top of the system dim.
    func sussDrawerDim(_ active: Bool) -> some View {
        overlay {
            if active {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)   // taps fall through to the system dim
            }
        }
        .animation(.easeInOut(duration: 0.25), value: active)
    }
}

struct SussConfirmDrawer: View {
    let title: String            // e.g. "CLOSE ROOM?" / "LEAVE ROOM?"
    let message: String
    var confirmLabel = "EXIT"
    var onConfirm: () -> Void
    var onCancel: () -> Void

    // Measured content height -> sheet detent, so the sheet hugs the content
    // exactly (no magic 280, no leftover gap).
    @State private var contentHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 16) {
                // Grabber: 64 wide, white 50% fill, white 70% OUTSIDE stroke 4.
                Capsule().fill(.white.opacity(0.5))
                    .overlay(Capsule().inset(by: -2)
                        .stroke(.white.opacity(0.7), lineWidth: 4))
                    .frame(width: 64, height: 10)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                IdentityTitle(text: title, size: 32, strokeWidth: 5,
                              fill: Color(hex: "2A1AE8"), stroke: Color(hex: "8FE0FF"),
                              tilt: 0)
                    .padding(.top, 6)

                Text(message)
                    .sussFont(.body2)              // design system: Body 2 (18 semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Buttons: 72pt tall (40 label + 2×16 style padding).
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        IdentityTitle(text: "CANCEL", size: 18, strokeWidth: 3, tilt: 0)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(SussButtonStyle(horizontalPadding: 16))

                    Button(action: onConfirm) {
                        IdentityTitle(text: confirmLabel, size: 18, strokeWidth: 3, tilt: 0)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(SussButtonStyle(
                        horizontalPadding: 16,
                        gradientColors: [Color(hex: "FFC1EB"), Color(hex: "EB0067")]))
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
            contentHeight = $0
        }
        .presentationDetents([.height(contentHeight)])
        .ignoresSafeArea(edges: .bottom)   // 56 counts to the PHYSICAL edge
        .presentationDragIndicator(.hidden)      // custom grabber above
        .presentationCornerRadius(40)
        .presentationBackground {
            // Top-align the image so its TOP edge sits at the drawer's top
            // (scaledToFill alone centers it).
            Color.clear
                .overlay(alignment: .top) {
                    Image("pink-bg")             // same bg as the homepage
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        }
    }
}

#Preview("Drawer — close room (host)") {
    Color(hex: "1A1A1A").ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SussConfirmDrawer(
                title: "CLOSE ROOM?",
                message: "Leaving closes room for everyone.",
                onConfirm: {},
                onCancel: {}
            )
        }
}

#Preview("Drawer — leave room (player)") {
    Color(hex: "1A1A1A").ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SussConfirmDrawer(
                title: "LEAVE ROOM?",
                message: "You'll leave the room and return to start.",
                onConfirm: {},
                onCancel: {}
            )
        }
}
#endif
