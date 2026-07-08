// RoleSuspectView.swift
// Role reveal screen — "you're the SUSPECT". Standalone for now.
//
// Animation: the suspect sticker starts SMALL in the middle of the screen and
// scales UP to full size with a little spring bounce (fading in as it grows).
// No sliding, no separate "you're the" — one sticker on the grouped bg.
//
// OWNER: Agung. LAYOUT ONLY.

import SwiftUI

struct RoleSuspectView: View {

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    private let stickerName = "youre-the-suspect-new"   // the role sticker
    private let bgName = "role-suspect-bg-white"        // grouped pink+white bg
    private let stickerWidth: CGFloat = 400             // final size
    private let startScale: CGFloat = 0.002               // size when it first appears
    private let stickerOffsetY: CGFloat = 30             // 0 = screen middle
    // ──────────────────────────────────────────────────────────────────────

    @State private var appeared = false

    var body: some View {
        ZStack {
            Image(bgName)
                .resizable()
                .ignoresSafeArea()

            // Sticker grows from `startScale` -> 1, centered (scaleEffect scales
            // about the center, so it "opens up" from the middle of the screen).
            Image(stickerName)
                .resizable()
                .scaledToFit()
                .frame(width: stickerWidth)
                .offset(y: stickerOffsetY)
                .scaleEffect(appeared ? 1 : startScale)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.4)) {
                appeared = true
            }
        }
    }
}

#Preview {
    RoleSuspectView()
}
