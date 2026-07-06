//
//  WhosNextView.swift
//  Sanscore
//
//  Created by Agung Ananda on 06/07/26.
//

import SwiftUI

struct WhosNextView: View {

    // ─────────────────────────────────────────────────────────────────────
    // TUNABLES — everything you need to reshape the light lives here.
    // Points are 0...1 fractions of the screen (0,0 = top-left, 1,1 = bottom-right).
    // ─────────────────────────────────────────────────────────────────────

    /// Where the light is brightest as it appears — put this over "LET'S".
    private let lightStart = UnitPoint(x: 0.30, y: 0.42)
    /// Where the light drifts to and fades out — put this over "BEGIN".
    private let lightEnd   = UnitPoint(x: 0.78, y: 0.60)

    /// Seconds for one full pass (start -> end). Bigger = slower, calmer lamp.
    private let cycle: Double = 4.0
    /// Diameter of the glow in points. Bigger = softer, wider pool of light.
    private let lightSize: CGFloat = 480
    /// Peak brightness, 0...1. Keep it low — it's a dim lamp, not a spotlight.
    private let maxGlow: Double = 0.55
    /// Extra blur on the glow. Higher = mushier, more lamp-like edge.
    private let glowBlur: CGFloat = 40

    /// Size of the word image.
    private let wordWidth: CGFloat = 300

    var body: some View {
        // TimelineView(.animation) re-renders every frame with the current time,
        // so we get smooth motion without any @State or manual animation.
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let size = geo.size
                let t = phase(for: timeline.date)          // 0 -> 1, loops

                // Interpolate position and brightness from t.
                let pos = lerp(lightStart, lightEnd, t, in: size)
                let glow = sinPulse(t) * maxGlow           // 0 at ends, peak mid

                ZStack {
                    // 1. Dark checkered background
                    Image("black-bg")
                        .resizable()
                        .ignoresSafeArea()

                    // 2. The moving lamp — a blurred white radial gradient.
                    //    .screen blend makes it ADD light to the bg (lighten),
                    //    so you never see a hard white disc, just a glow.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: lightSize / 2
                            )
                        )
                        .frame(width: lightSize, height: lightSize)
                        .blur(radius: glowBlur)
                        .blendMode(.screen)
                        .position(pos)
                        .opacity(glow)

                    // 3. The word, on top so the light rims and backlights it.
                    Image("whos-next")
                        .resizable()
                        .scaledToFit()
                        .frame(width: wordWidth)
                }
            }
        }
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────

    /// Turn a wall-clock date into a looping 0...1 value using `cycle`.
    private func phase(for date: Date) -> Double {
        let seconds = date.timeIntervalSinceReferenceDate
        return (seconds.truncatingRemainder(dividingBy: cycle)) / cycle
    }

    /// Straight-line interpolate between two UnitPoints, in real pixels.
    private func lerp(_ a: UnitPoint, _ b: UnitPoint, _ t: Double, in size: CGSize) -> CGPoint {
        let x = a.x + (b.x - a.x) * t
        let y = a.y + (b.y - a.y) * t
        return CGPoint(x: x * size.width, y: y * size.height)
    }

    /// Bright in the middle of the pass, dark at both ends: fade in, fade out.
    /// sin(π·t) = 0 at t=0, 1 at t=0.5, 0 at t=1. Smooth, seamless loop.
    private func sinPulse(_ t: Double) -> Double {
        sin(t * .pi)
    }
}

#Preview {
    WhosNextView()
}
