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
            // Same dark "box of balls" bg as the game room.
            Image("gameroom-host-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                SussText(text: "PICKING\nROLES", style: .displayTitle,
                         fill: .white, stroke: Color(hex: "9A9A9A"), tilt: -3)
                .padding(.top, 60)
                .multilineTextAlignment(.center)
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

    // Breathing: fast, rushed pulse (~0.82…1.18), each bubble on its own phase.
    private func breathe(_ i: Int, _ t: Double) -> CGFloat {
        1 + CGFloat(sin(t * 3.8 + Double(i) * 1.7)) * 0.18
    }

    // Roam: cluster near the MIDDLE and mill around it. Tight base ring +
    // small sine drift so the bubbles stay hugging the center of the screen.
    private func drift(_ i: Int, _ count: Int, _ size: CGSize, _ t: Double) -> CGPoint {
        let cx = size.width / 2
        // Slightly above the geometric middle — the title up top + bottom safe
        // area make a 0.5 anchor read as "low"; 0.45 LOOKS centered.
        let cy = size.height * 0.45
        let angle = Double(i) / Double(max(1, count)) * 2 * .pi
        let ring = Double(min(size.width, size.height)) * 0.12   // tight -> near middle
        let baseX = cx + CGFloat(cos(angle)) * CGFloat(ring)
        let baseY = cy + CGFloat(sin(angle)) * CGFloat(ring)
        let phase = Double(i) * 1.3
        let driftX = CGFloat(sin(t * 0.55 + phase)) * 26         // small roam, stays central
        let driftY = CGFloat(cos(t * 0.47 + phase * 1.3)) * 26
        return CGPoint(x: baseX + driftX, y: baseY + driftY)
    }
}

#Preview {
    PickingRolesView(players: ["a", "b", "c", "d"], avatars: [:],
                     displayNames: ["a": "AGUNG", "b": "MARLEEN", "c": "SATRIA", "d": "PAFRAS"],
                     colorIndex: ["a": 3, "b": 4, "c": 2, "d": 1])
}
#endif
