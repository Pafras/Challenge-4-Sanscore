// SyncingView.swift
// Shown on GameState.syncing — the reveal barrier. This device finished
// calibrating and is waiting for every other phone before the LET'S BEGIN /
// picking-roles reveal, so all screens flip together (see reportReady in the
// view model). Usually a blink on later rounds; a couple of seconds on round 1.
//
// Dark checkered bg + a breathing "DONE CALIBRATING" + loading spinner so the
// hand-off into the reveal (same dark bg) is seamless. Reads nothing, computes
// nothing.

import SwiftUI

struct SyncingView: View {
    @State private var pulse = false
    var colorindex: [String: Int] = [:]
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()
            VStack(spacing: 16) {
                // Marleen's SussText component with a white stroke + the same hard
                // black drop shadow PickingRolesView uses on its title.
                SussText(text: "DONE\nCALIBRATING", style: .displayTitle,
                         fill: .white, stroke: .white.opacity(0.5), strokeWidth: 4)
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 3, y: 4)
                    .scaleEffect(pulse ? 1.04 : 0.96)
                    .opacity(pulse ? 1 : 0.75)
                Text("Waiting for others...")
                    .sussFont(.body1)
                    .fontWidth(.expanded)
                    .foregroundStyle(.white.opacity(0.85))
                ProgressView()
                    .tint(.white)
                    .padding(.top, 4)
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
