// SwipeToEnterView.swift
// Screen 4 — "You're all set" swipe-to-enter (Figma: "Slide to enter" /
// "YOU'RE ALL SET!!"). NEW screen — not wired into the flow yet.
//
// OWNER: Agung (layout) + Pafras (wiring).
//   - Agung: style this to Figma. LAYOUT ONLY.
//   - Pafras: add the GameState case + vm method, then pass a real `onEnter`
//     closure (e.g. { vm.start() }) and add it to the GameFlowView switch.
//
// Right now it's a standalone stub with a placeholder swipe. It calls onEnter
// when the user swipes down past the threshold. See HANDOFF-UI.md.

import SwiftUI

struct SwipeToEnterView: View {
    // Pafras wires this to a real vm action later. Default = no-op so the
    // preview and stub compile on their own.
    var onEnter: () -> Void = {}

    @State private var dragY: CGFloat = 0
    private let threshold: CGFloat = 120

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("YOU'RE ALL SET!!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Spacer()
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .offset(y: dragY)
            Text("Swipe down to enter")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { dragY = max(0, $0.translation.height) }
                .onEnded { value in
                    if value.translation.height > threshold {
                        onEnter()
                    }
                    dragY = 0
                }
        )
    }
}

#Preview {
    SwipeToEnterView()
}
