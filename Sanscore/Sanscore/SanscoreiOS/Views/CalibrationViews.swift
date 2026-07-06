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
            Image("black-bg")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("LETS\nCALIBRATE")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                // Stand-in for the Figma hand-on-phone illustration.
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.9))

                Text("Put your pointy finger on the camera")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
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
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.top, 80)

                Spacer()

                Text("\u{201C} I swear that\nI'm telling the truth \u{201D}")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Spacer()

                VStack(spacing: 2) {
                    Text(bpm.map(String.init) ?? "--")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(bpm ?? 0)))
                        .animation(.snappy, value: bpm)
                    Text("BPM")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview("Lets Calibrate") { LetsCalibrateView() }
#Preview("Measuring") { MeasuringHeartRateView(bpm: 69) }
