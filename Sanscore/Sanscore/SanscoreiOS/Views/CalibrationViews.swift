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

                Text("\u{201C} I swear that\nI'm telling the truth \u{201D}")
                    .font(.system(size: 22, weight: .bold))
                    .fontWidth(.expanded)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

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
    }
}

#Preview("Lets Calibrate") { LetsCalibrateView() }
#Preview("Measuring") { MeasuringHeartRateView(bpm: 69) }
