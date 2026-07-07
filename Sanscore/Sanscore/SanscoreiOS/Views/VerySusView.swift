//
//  VerySusView.swift
//  Sanscore
//
//  Created by Agung Ananda on 07/07/26.
//
//  The "100% SUSS!!" result screen (the most-sus of the four verdicts).
//
//  The percentage is DYNAMIC (0–100). It's drawn from the digit image assets
//  ("0"…"9" and "%") — a hand-made bitmap "font" — so it always matches the
//  Figma look. See PercentageText below.
//
//  Entrance animation, in order:
//    1. the percentage number fades + pops in,
//    2. ~at the same time, result-white-bg eases in (diagonal band slides down),
//    3. result-very-sus (eyes + "SUSS!!") stamps in with a spring bounce.
//
//  Assets: result-red-bg (background), result-white-bg (diagonal band),
//  result-very-sus (eyes + wordmark), 0…9 + % (the number "font").
//
//  Standalone — buttons are no-ops by default. Pass real closures + values to
//  wire it into the game flow.
//

import SwiftUI

struct VerySusView: View {

    // ── INPUTS (wire points) ──────────────────────────────────────────────
    /// The sus score to show, 0…100.
    var percent: Int = 100
    /// The blurb under the stamp.
    var message: String = "Your heart rate increased significantly while speaking, and your voice showed noticeable stress characteristics."
    /// "READY (x/y)" counters.
    var readyCount: Int = 3
    var totalPlayers: Int = 4
    var onReady: () -> Void = {}
    var onLeave: () -> Void = {}

    /// If the result-very-sus asset ALREADY bakes in the number, set this false
    /// to hide the separate digit overlay (avoids a double "100%").
    var showDigitPercent: Bool = true
    // ──────────────────────────────────────────────────────────────────────

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    private let stampWidth: CGFloat = 340     // result-very-sus size
    private let numberHeight: CGFloat = 66    // digit height for the percentage
    private let numberOffsetY: CGFloat = 8    // nudge the number into the art's gap
    // ──────────────────────────────────────────────────────────────────────

    // Animation gates.
    @State private var showNumber = false
    @State private var showWhite  = false
    @State private var showStamp  = false
    @State private var showText   = false

    var body: some View {
        ZStack {
            // Background
            Image("result-red-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // (2) White diagonal band — eases in from up-left.
            Image("result-white-bg")
                .resizable()
                .frame(width: 400, height: 200)
                .ignoresSafeArea()
                .opacity(showWhite ? 1 : 0)
                .offset(x: showWhite ? 0 : 120, y: showWhite ? 0 : -60)

            VStack(spacing: 20) {
                Spacer()

                // Stamp cluster: the eyes+wordmark art, with the dynamic number
                // sitting on top (higher z so it stays visible as the art stamps).
                ZStack {
                    // (3) result-very-sus stamps in.
                    Image("result-very-sus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: stampWidth)
                        .scaleEffect(showStamp ? 1 : 2.6)
                        .opacity(showStamp ? 1 : 0)

                    // (1) The dynamic percentage, drawn from digit images.
                    if showDigitPercent {
                        PercentageText(value: percent, digitHeight: numberHeight)
                            .offset(y: numberOffsetY)
                            .scaleEffect(showNumber ? 1 : 0.6)
                            .opacity(showNumber ? 1 : 0)
                            .zIndex(1)
                    }
                }

                // Blurb
                Text(message)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .opacity(showText ? 1 : 0)

                Spacer()

                // Bottom row: leave (icon) + READY pill.
                HStack(spacing: 16) {
                    Button(action: onLeave) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                    }
                    .glassButton()

                    Button(action: onReady) {
                        Text("READY (\(readyCount)/\(totalPlayers))")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.45, blue: 0.72),
                                                 Color(red: 0.93, green: 0.16, blue: 0.53)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                            )
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(showText ? 1 : 0)
            }
        }
        .onAppear(perform: runIntro)
    }

    // MARK: - Entrance sequence

    private func runIntro() {
        // (1) number + (2) white band start together.
        withAnimation(.easeOut(duration: 0.45)) { showNumber = true }
        withAnimation(.easeOut(duration: 0.55)) { showWhite  = true }

        // (3) stamp lands after the band has eased in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) { showStamp = true }
        }
        // Text + buttons fade in last.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.4)) { showText = true }
        }
    }
}

// MARK: - Digit-image "font"

/// Renders an integer + "%" using the hand-made digit image assets ("0"…"9",
/// "%"). Each glyph keeps its natural width at a fixed height, so any number
/// 0…100 lays out correctly.
struct PercentageText: View {
    var value: Int
    var digitHeight: CGFloat = 66
    var spacing: CGFloat = 2

    private var glyphs: [String] {
        (String(max(0, value)) + "%").map(String.init)
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { _, g in
                Image(g)
                    .resizable()
                    .scaledToFit()
                    .frame(height: digitHeight)
            }
        }
    }
}

#Preview("100%") {
    VerySusView(percent: 100)
}

#Preview("73%") {
    VerySusView(percent: 73)
}
