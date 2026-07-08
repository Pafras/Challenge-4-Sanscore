//
//  KindaSusView.swift
//  Sanscore
//
//  Created by Agung Ananda on 07/07/26.
//

import SwiftUI

struct KindaSusView: View {

    // ── INPUTS (wire points) ──────────────────────────────────────────────
    /// The sus score to show, 0…100.
    var percent: Int = 100

    /// The suspect's PEAK (highest) heart rate during the answer. nil -> "--".
    /// TODO(pafras): pass the peak HR, e.g. KindaSusView(peakBPM: vm.peakBPM)
    var peakBPM: Int? = 120

    /// The blurb under the stamp. This is meant to hold the **AI summary** —
    /// the Foundation Models (LLM) one-liner explaining *why* the score came out
    /// this way (see StructureAnalyzer). It's Optional so wiring is trivial:
    ///   • nil  -> shows a neutral "analyzing…" placeholder (LLM not ready / off)
    ///   • text -> shows that text
    /// TODO(pafras): pass the LLM output, e.g.
    ///     VerySusView(summary: vm.aiSummary)      // vm.aiSummary: String?
    /// A sensible default is provided so the standalone screen still reads well.
    var summary: String? = "Your heart rate increased significantly while speaking, and your voice showed noticeable stress characteristics."

    /// "READY (x/y)" counters.
    var readyCount: Int = 3
    var totalPlayers: Int = 4
    var onReady: () -> Void = {}
    var onLeave: () -> Void = {}

    /// If the result-very-sus asset ALREADY bakes in the number, set this false
    /// to hide the separate digit overlay (avoids a double "100%").
    var showDigitPercent: Bool = true

    /// True once every player has tapped ready — unlocks the READY button.
    private var allReady: Bool { readyCount >= totalPlayers }
    /// What to show under the stamp: the AI summary, or a placeholder if absent.
    private var summaryText: String { summary ?? "Analyzing your answer…" }
    // ──────────────────────────────────────────────────────────────────────

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    private let stampWidth: CGFloat = 320     // result-very-sus size
    private let numberHeight: CGFloat = 62     // digit height for the percentage
    private let numberOffsetY: CGFloat = 36     // nudge the number into the art's gap
    private let bandWidth: CGFloat = 400       // result-white-bg width (kept proportional)
    private let bandOffsetY: CGFloat = -110     // where the band sits behind the stamp
    private let clusterTopGap: CGFloat = 170    // gap above the stamp cluster
    // ──────────────────────────────────────────────────────────────────────

    // Animation gates.
    @State private var showNumber = false
    @State private var showWhite  = false
    @State private var showStamp  = false
    @State private var showText   = false

    var body: some View {
        ZStack {
            // Background
            Image("result-orange-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // (2) White diagonal band — proportional (scaledToFit, not stretched)
            //     and sized to sit behind the stamp. Eases in by sliding FORWARD
            //     along its own diagonal (up-left -> place), not dropping from the top.
            Image("result-white-bg-2")
                .resizable()
                .scaledToFit()
                .frame(width: bandWidth)
                .offset(x: showWhite ? 0 : -70,
                        y: bandOffsetY + (showWhite ? 0 : -70))
                .opacity(showWhite ? 1 : 0)

            VStack(spacing: 12) {
                Spacer().frame(height: clusterTopGap)

                // Stamp cluster: the eyes+wordmark art, with the dynamic number
                // sitting on top (higher z so it stays visible as the art stamps).
                ZStack {
                    // (3) result-very-sus stamps in.
                    Image("kinda-sus")
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

                // Blurb — pulled up close under the stamp (stamp art has
                // transparent padding, so a negative top offset tightens the gap).
                Spacer()
                Text(summaryText)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.top, -24)
                    .opacity(showText ? 1 : 0)

                PeakBPMCard(peakBPM: peakBPM)
                    .padding(.top, 12)
                    .opacity(showText ? 1 : 0)

                Spacer()

                // Bottom row: leave (left edge) + READY (right edge).
                // A Spacer pushes them to opposite ends, matching the design.
                HStack(spacing: 0) {
                    Button(action: onLeave) {
                        Image("exit-button")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                    }

                    Spacer(minLength: 12)

                    // READY — the button art itself conveys enabled/disabled:
                    // ACTIVE only when everyone is ready, INACTIVE otherwise. Taps
                    // are blocked until then (.disabled), matching the visual.
                    Button(action: onReady) {
                        ZStack {
                            Image(allReady ? "player-placeholder-active"
                                           : "player-placeholder-inactive")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 76)
                            Text("READY (\(readyCount)/\(totalPlayers))")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(!allReady)
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

// NOTE: PercentageText lives in VerySusView.swift — it's shared across all the
// result screens, so it is NOT redeclared here (doing so is a compile error).

#Preview("100% — waiting (3/4)") {
    KindaSusView(percent: 100, readyCount: 3, totalPlayers: 4)   // READY inactive
}

#Preview("100% — all ready (4/4)") {
    KindaSusView(percent: 100, readyCount: 4, totalPlayers: 4)   // READY active
}
