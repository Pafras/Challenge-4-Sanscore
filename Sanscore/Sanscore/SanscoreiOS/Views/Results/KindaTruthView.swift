//
//  KindaTruthView.swift
//  Sanscore
//
//  Created by Agung Ananda on 07/07/26.
//

import SwiftUI

struct KindaTruthView: View {

    // ── INPUTS (wire points) ──────────────────────────────────────────────
    /// The sus score to show, 0…100.
    var percent: Int = 100

    /// The suspect's PEAK (highest) heart rate during the answer. nil -> "--".
    /// TODO(pafras): pass the peak HR, e.g. KindaTruthView(peakBPM: vm.peakBPM)
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
    /// True once THIS device tapped ready — locks the button (waiting for others).
    var iAmReady: Bool = false
    var onReady: () -> Void = {}
    var onLeave: () -> Void = {}

    /// If the result-very-sus asset ALREADY bakes in the number, set this false
    /// to hide the separate digit overlay (avoids a double "100%").
    var showDigitPercent: Bool = true

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
            Image("result-yellow-bg 1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // (2) White diagonal band — proportional (scaledToFit, not stretched)
            //     and sized to sit behind the stamp. Eases in by sliding FORWARD
            //     along its own diagonal (up-left -> place), not dropping from the top.
            Image("result-white-bg-3")
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
                    Image("kinda-truth")
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
                    // Leave — design-system circular action button (code, not art).
                    Button(action: onLeave) {
                        StrokedIcon(systemName: "xmark", assetName: "icon-close",
                                    size: 22, fill: Color(hex: "E40063"), stroke: .white)
                            .frame(width: 72, height: 72)
                    }
                    .glassButton()

                    Spacer(minLength: 12)

                    // READY — ACTIVE until THIS player taps, then INACTIVE (locked,
                    // waiting for the others). The count shows how many have readied;
                    // the host starts the next round once everyone's in.
                    Button(action: onReady) {
                        IdentityTitle(text: "READY (\(readyCount)/\(totalPlayers))",
                                      size: 20, strokeWidth: 3, tilt: 0)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(SussButtonStyle(
                        horizontalPadding: 24,
                        gradientColors: [Color(hex: "FFC1EB"), Color(hex: "EB0067")]))
                    .disabled(iAmReady)
                    .opacity(iAmReady ? 0.55 : 1)   // locked once I'm ready
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
            Haptics.notify(.success)   // truth verdict
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
    KindaTruthView(percent: 100, readyCount: 3, totalPlayers: 4)   // READY inactive
}

#Preview("100% — all ready (4/4)") {
    KindaTruthView(percent: 100, readyCount: 4, totalPlayers: 4)   // READY active
}
