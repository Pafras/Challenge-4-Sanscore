// PickingRolesView.swift
// Shown on GameState.roleReveal (replaces the old colour-roulette). The lobby
// player bubbles float around and "breathe" (scale big/small) while the host
// picks this round's roles. Pure time-driven animation — NO gyroscope/CoreMotion,
// so it runs identically on Simulator and device.
//
// After ~1.6s applyTurn advances to .roleResult (the per-role reveal screen).
//
// OWNER: Pafras. Reads the same vm data the lobby bubbles use.

import SwiftUI
#if os(iOS)

struct PickingRolesView: View {
    let players: [String]
    let avatars: [String: Data]
    var displayNames: [String: String] = [:]
    var colorIndex: [String: Int] = [:]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()

            VStack {
                Text("PICKING\nROLES")
                    .font(.system(size: 46, weight: .black)).fontWidth(.expanded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 3, y: 4)
                    .padding(.top, 60)
                Spacer()
            }

            // Floating, breathing bubbles.
            GeometryReader { geo in
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ForEach(Array(players.enumerated()), id: \.element) { i, id in
                        bubble(id)
                            .scaleEffect(breathe(i, t))          // big/small
                            .position(drift(i, players.count, geo.size, t))  // roam
                    }
                }
            }
        }
    }

    // MARK: bubble

    private func bubble(_ id: String) -> some View {
        let palette = IdentityPalette.colors
        let idx = min(max(0, colorIndex[id] ?? 0), palette.count - 1)
        return VStack(spacing: 0) {
            ZStack {
                if let data = avatars[id], let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Circle().fill(palette[idx])
                }
            }
            .frame(width: 78, height: 78)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
            .overlay(alignment: .bottom) {
                IdentityTitle(text: (displayNames[id] ?? id).uppercased(),
                              size: 18, strokeWidth: 4, fill: palette[idx], tilt: 0)
                    .offset(y: 11)
            }
        }
    }

    // MARK: motion (time-only, no CoreMotion)

    // Breathing: scale oscillates 0.9…1.1, each bubble on its own phase.
    private func breathe(_ i: Int, _ t: Double) -> CGFloat {
        1 + CGFloat(sin(t * 1.6 + Double(i) * 1.7)) * 0.10
    }

    // Roam: scatter around center in a ring, plus a slow sine drift per bubble.
    private func drift(_ i: Int, _ count: Int, _ size: CGSize, _ t: Double) -> CGPoint {
        let cx = size.width / 2
        let cy = size.height * 0.5
        let angle = Double(i) / Double(max(1, count)) * 2 * .pi
        let ring = Double(min(size.width, size.height)) * 0.26
        let baseX = cx + CGFloat(cos(angle)) * CGFloat(ring)
        let baseY = cy + CGFloat(sin(angle)) * CGFloat(ring)
        let phase = Double(i) * 1.3
        let driftX = CGFloat(sin(t * 0.5 + phase)) * 26
        let driftY = CGFloat(cos(t * 0.42 + phase * 1.3)) * 26
        return CGPoint(x: baseX + driftX, y: baseY + driftY)
    }
}

#Preview {
    PickingRolesView(players: ["a", "b", "c", "d"],
                     displayNames: ["a": "AGUNG", "b": "MARLEEN", "c": "SATRIA", "d": "PAFRAS"],
                     colorIndex: ["a": 3, "b": 4, "c": 2, "d": 1])
}
#endif
