// CalibrationViews.swift
// The Figma calibration sequence (host taps START -> every player calibrates):
//
//   LetsCalibrateView         "LETS CALIBRATE" + hand, put finger on camera
//   (WarningView)             reused from WarningView.swift — live camera bg
//   MeasuringHeartRateView    red screen, "I swear..." phrase, live BPM
//
// GameFlowView switches between them on vm.calibrationPhase. Layout is a
// plain-SwiftUI stand-in for Satria's art — restyle freely, keep struct names.
//
// OWNER: Pafras (flow) / Agung + Marleen (restyle).

import SwiftUI

// MARK: - "LETS CALIBRATE"

struct LetsCalibrateView: View {
    var body: some View {
        ZStack {
            Spacer()
            Image("black-bg")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                SussText(text: "LETS\nCALIBRATE", style: .displayTitle,
                         fill: .white, stroke: Color(hex: "9A9A9A"))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
                Text("Put your pointy finger on the camera")
                    .sussFont(.body1)              // design system: Body 1 (20)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                CalibrateHandAnimation()
                    .padding(.top, 48)
            }
            .padding(.bottom, 20)
            VStack {
                Spacer()
                Text("Tap anywhere to continue")
                    .sussFont(.body2)             // design system: Body 2 (18)
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 14)
        }
    }
}

// Phone (static) + hand whose index finger swings onto the top-left camera
// lens and covers it (covered pose = the reference art), then swings back —
// smooth, looping, with a dwell while covered. No pulse/LED overlay.
// The two SVGs are separate art, so offsets are tuned by eye — nudge the
// constants below in the Xcode preview if alignment drifts.
private struct CalibrateHandAnimation: View {
    @State private var onLens = false   // finger off (side) vs covering the lens

    private let phoneW: CGFloat = 190

    // Hand rest pose = REFERENCE (fingertip covering the top-left lens). Raised
    // so the finger reaches the lens, not sitting below it.
    private let handRestX: CGFloat = -5
    private let handRestY: CGFloat = -20
    // Hand.svg is ONE path (finger not separable), so we pivot the whole hand
    // at the wrist: a small angle swings the far fingertip sideways while the
    // wrist barely moves — reads as "the finger" moving on/off the lens.
    private let swingAngle: CGFloat = 7   // degrees off-lens

    // Timing: smooth swing, then DWELL covering the lens before swinging back.
    private let swingDur = 1.1            // slow easeInOut = smooth
    private let dwellCovered = 1.6        // hold on the lens (reference pose)
    private let dwellOff = 0.6

    var body: some View {
        ZStack {
            Image("calibrate-phone")
                .resizable()
                .scaledToFit()
                .frame(width: phoneW)
                .offset(y: -60)

            // Hand in front. Rotates a few degrees around the wrist so only the
            // fingertip swings onto the lens (covered pose = reference).
            Image("calibrate-hand")
                .resizable()
                .scaledToFit()
                .frame(width: phoneW * 1.32)
                .rotationEffect(.degrees(onLens ? 0 : Double(swingAngle)),
                                anchor: .bottom)
                .offset(x: handRestX, y: handRestY)
        }
        // Smooth swing with a dwell at each end.
        .task {
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: swingDur)) { onLens = true }
                try? await Task.sleep(for: .seconds(swingDur + dwellCovered))
                withAnimation(.easeInOut(duration: swingDur)) { onLens = false }
                try? await Task.sleep(for: .seconds(swingDur + dwellOff))
            }
        }
    }
}

// MARK: - "MEASURING HEART RATE"

struct MeasuringHeartRateView: View {
    /// Live rolling BPM readout; nil -> "--" until there's enough signal.
    var bpm: Int?

    @State private var heartbeat = HeartbeatHaptic()   // phone beats at the live BPM

    var body: some View {
        ZStack {
            Image("red-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // ECGLine lives in SuspectHoldToAnswerView.swift (same module);
            // its beat rate follows the live reading.
            ECGLine(bpm: bpm)
                .frame(height: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 66)
                .ignoresSafeArea(edges: .horizontal)
                .allowsHitTesting(false)

            VStack {
                Text("MEASURING\nHEART RATE")
                    .font(.system(size: 36, weight: .heavy))
                    .fontWidth(.expanded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.top, 80)

                Spacer()

                KaraokeOath()

                Spacer()

                VStack(spacing: 2) {
                    Text(bpm.map(String.init) ?? "--")
                        .font(.system(size: 40, weight: .heavy))
                        .fontWidth(.expanded)
                        .contentTransition(.numericText(value: Double(bpm ?? 0)))
                        .animation(.snappy, value: bpm)
                    Text("BPM")
                        .font(.system(size: 15, weight: .semibold))
                        .fontWidth(.expanded)
                }
                .foregroundStyle(.white)
                .padding(.bottom, 40)
            }
        }
        .task { heartbeat.start(bpm: bpm) }
        .onChange(of: bpm) { _, new in heartbeat.setBPM(new) }
        .onDisappear { heartbeat.stop() }
    }
}

// Spotify-style karaoke: a bright gradient wipes left->right THROUGH the letters
// over ~8s (the HR capture window) — a continuous pixel-level sweep, not per
// word. Each line gets a slice of the timeline (weighted by length) so the wipe
// flows line 1 -> line 2 like reading.
// ponytail: two fixed lines (not a flow-wrap layout) — matches the design's
// line break. If the phrase changes, edit the `lines` array.
private struct KaraokeOath: View {
    private let lines = ["\u{201C} I swear that", "I'm telling the truth \u{201D}"]
    private let duration = 8.0
    @State private var start = Date()
    
    var body: some View {
        TimelineView(.animation) { ctx in
            let elapsed = ctx.date.timeIntervalSince(start)
            let p = min(max(elapsed / duration, 0), 1)   // 0..1 overall
            let progress = lineProgress(p)
            VStack(spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    SweepLine(text: line, progress: progress[i])
                }
            }
        }
        .font(.system(size: 30, weight: .bold))
        .fontWidth(.expanded)                 // Marleen's typography system
        .foregroundStyle(.white)
        .onAppear { start = Date() }
    }
    
    // Split the 0..1 timeline across lines, weighted by character count, so the
    // wipe spends longer on longer lines and reads left->right, top->bottom.
    private func lineProgress(_ p: Double) -> [Double] {
        let counts = lines.map { Double($0.count) }
        let total = counts.reduce(0, +)
        var result: [Double] = []
        var before = 0.0
        for c in counts {
            let s = before / total, e = (before + c) / total
            result.append(min(max((p - s) / (e - s), 0), 1))
            before += c
        }
        return result
    }
}

// One line: dim base text with a bright copy masked by a gradient whose bright
// edge slides left->right as `progress` goes 0->1. The soft ±0.08 edge is the
// moving light.
private struct SweepLine: View {
    let text: String
    let progress: Double

    var body: some View {
        Text(text)
            .opacity(0.3)
            .overlay(
                Text(text).mask(
                    LinearGradient(
                        stops: [
                            // Bright fills [0, progress] with a soft trailing edge.
                            // clear stop sits AT `progress` so progress==0 = fully
                            // dim (no left-edge glow before this line's turn).
                            .init(color: .white, location: 0),
                            .init(color: .white, location: max(0, progress - 0.08)),
                            .init(color: .clear, location: progress),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )
    }
}

#Preview("Lets Calibrate") { LetsCalibrateView() }
#Preview("Measuring") { MeasuringHeartRateView(bpm: 69) }
