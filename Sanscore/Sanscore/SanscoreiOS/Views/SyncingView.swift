// SyncingView.swift
// Shown on GameState.syncing — the reveal barrier. This device finished
// calibrating and is waiting for every other phone before the LET'S BEGIN /
// picking-roles reveal, so all screens flip together (see reportReady in the
// view model). Usually a blink on later rounds; a couple of seconds on round 1.
//
// Dark checkered bg + a breathing "GET READY" so the hand-off into the reveal
// (same dark bg) is seamless — no jarring flash. Reads nothing, computes nothing.

import SwiftUI

struct SyncingView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                IdentityTitle(text: "GET READY", size: 34, tilt: 0)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                    .opacity(pulse ? 1 : 0.7)
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    SyncingView()
}
