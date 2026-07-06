//
//  SuspectHoldToAnswerView.swift
//  Sanscore
//
//  Created by Agung Ananda on 06/07/26.
//
//  The SUSPECT's answering screen. The mic button has three looks, one screen:
//    • DISABLED (isEnabled == false): frosted, faded, not holdable. Shown while
//      the interrogator is still asking. A subtitle explains the wait.
//    • IDLE     (enabled, not holding): frosted glass circle + pink mic.
//    • ANSWER   (holding):              glass circle + pulsing waveform bars.
//
//  The button is Liquid Glass (.glassEffect) — the native iOS translucent
//  material — so it refracts the red background instead of being a solid fill.
//
//  Assets used: red-bg (background), answer-the-question (title art),
//  mic-logo (the pink mic icon). Waveform bars are drawn natively so they dance.
//
//  Native iOS touches: Liquid Glass button, taptic feedback on hold/release
//  (.sensoryFeedback), numeric-roll BPM (.contentTransition(.numericText)),
//  button a11y traits.
//
//  Standalone — not wired into the game flow yet.
//

import SwiftUI

struct SuspectHoldToAnswerView: View {

    // ── HEART RATE (wire point) ───────────────────────────────────────────
    // TODO(pafras): feed the live reading in here. Optional on purpose:
    //   • nil -> "--" (calibrating / no finger)   • Int -> shown, digits roll
    //     SuspectHoldToAnswerView(bpm: vm.currentBPM)   // vm.currentBPM: Int?
    var bpm: Int? = 69

    // ── ENABLED (wire point) ──────────────────────────────────────────────
    // TODO(pafras): the suspect can only answer AFTER the interrogator finishes
    // asking. Pass false while the question is being asked, flip to true when
    // the interrogator releases their button:
    //     SuspectHoldToAnswerView(isEnabled: vm.canAnswer)
    var isEnabled: Bool = true
    // ──────────────────────────────────────────────────────────────────────

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    private let circleSize: CGFloat = 240      // diameter of the mic button
    private let titleWidth: CGFloat = 320      // title art width
    private let barCount = 9                    // number of waveform bars
    // ──────────────────────────────────────────────────────────────────────

    @State private var isHolding = false

    var body: some View {
        ZStack {
            Image("red-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Full-width ECG line, pinned near the bottom behind the BPM readout.
            ECGLine(bpm: bpm)
                .frame(height: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 66)              // lift so the number sits on it
                .ignoresSafeArea(edges: .horizontal)
                .allowsHitTesting(false)

            VStack {
                Image("press-hold-to-answer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: titleWidth)
                    .padding(.top, 24)
                    .offset(y: 60)

                // Only shown while disabled — explains why the button is inert.
                if !isEnabled {
                    Text("The button will be active after\ninvestigator done asking.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 80)
                        .transition(.opacity)
                }

                Spacer()

                MicHoldButton(
                    size: circleSize,
                    barCount: barCount,
                    isEnabled: isEnabled,
                    isHolding: $isHolding
                )

                Spacer()

                // BPM readout. "--" until a reading arrives; digits roll natively.
                // A live ECG line scrolls behind it — its beat rate follows `bpm`.
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
        .animation(.easeInOut, value: isEnabled)
    }
}

// MARK: - Shared hold-to-talk mic button (Liquid Glass)

/// Frosted glass circle you hold to talk. Pink mic when idle, pulsing waveform
/// while held. Goes faded + inert when `isEnabled` is false.
/// Used by both the suspect (answer) and interrogator (question) screens.
struct MicHoldButton: View {
    var size: CGFloat
    var barCount: Int
    var isEnabled: Bool
    @Binding var isHolding: Bool

    var body: some View {
        ZStack {
            if isHolding {
                WaveformBars(barCount: barCount)
                    .frame(width: size * 0.5, height: size * 0.42)
                    .transition(.opacity)
            } else {
                Image("mic-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.30)
                    .opacity(isEnabled ? 1 : 0.5)     // faded when disabled
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        // Liquid Glass — the native translucent material. .interactive() lets it
        // react to touch. Falls back gracefully on the circle shape.
        .glassEffect(.regular.interactive(), in: Circle())
        .overlay(
            Circle().strokeBorder(.white.opacity(isEnabled ? 0.35 : 0.2), lineWidth: 2)
        )
        .opacity(isEnabled ? 1 : 0.65)
        .scaleEffect(isHolding ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHolding)
        .contentShape(Circle())
        // Hold anywhere on the circle: press = start, release = stop.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isHolding { isHolding = true } }
                .onEnded { _ in isHolding = false }
        )
        .disabled(!isEnabled)                          // no touches when disabled
        // Native taptic feedback on start (firm) / release (light).
        .sensoryFeedback(trigger: isHolding) { _, holding in
            holding ? .impact(weight: .medium) : .impact(weight: .light)
        }
        .accessibilityLabel("Hold to talk")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Native pulsing waveform

/// A row of vertical bars whose heights ripple like a live audio meter.
/// Driven by TimelineView so it animates on its own — no state, no timers.
struct WaveformBars: View {
    var barCount: Int
    /// Speed of the ripple. Bigger = faster dance.
    var speed: Double = 6.0
    /// Bar colour.
    var color: Color = .white

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let barWidth = geo.size.width / CGFloat(barCount * 2 - 1)
                HStack(spacing: barWidth) {
                    ForEach(0..<barCount, id: \.self) { i in
                        Capsule()
                            .fill(color)
                            .frame(width: barWidth, height: height(i, t, geo.size.height))
                    }
                }
                .frame(height: geo.size.height, alignment: .center)
            }
        }
    }

    private func height(_ i: Int, _ t: Double, _ maxH: CGFloat) -> CGFloat {
        let wave = sin(t * speed + Double(i) * 0.9)   // -1...1
        let norm = (wave + 1) / 2                      // 0...1
        return maxH * (0.25 + 0.75 * CGFloat(norm))    // 25%...100% tall
    }
}

// MARK: - Animated ECG (heartbeat) line

/// A scrolling ECG trace, like a hospital monitor. The scroll speed follows
/// `bpm`: one full PQRST beat every 60/bpm seconds, so a higher heart rate makes
/// the beats fly by faster. Falls back to 60 bpm when there's no reading, so it
/// still animates. Drawn with Canvas for smoothness.
struct ECGLine: View {
    /// The live heart rate. Drives how fast beats scroll.
    var bpm: Int?
    var color: Color = .white.opacity(0.55)
    /// Horizontal pixels between beats. Wider = more spread-out trace.
    var beatWidth: CGFloat = 130
    var lineWidth: CGFloat = 3

    /// Seconds per beat = 60 / bpm. Clamped so it never goes silly-fast/slow.
    private var period: Double {
        let b = Double(min(max(bpm ?? 60, 30), 200))
        return 60.0 / b
    }

    /// One heartbeat as (x, y) points in 0...1 space (y up = positive).
    /// Flat baseline → small P bump → sharp QRS spike → T bump → flat.
    private static let beat: [(CGFloat, CGFloat)] = [
        (0.00, 0.00), (0.12, 0.00),
        (0.16, 0.12), (0.20, 0.00),          // P wave
        (0.30, 0.00),
        (0.34, -0.18),                        // Q dip
        (0.38, 1.00),                         // R spike
        (0.42, -0.45),                        // S dip
        (0.46, 0.00), (0.60, 0.00),
        (0.68, 0.30), (0.78, 0.00),           // T wave
        (1.00, 0.00)
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let speed = beatWidth / period                       // px per second
                let scroll = CGFloat(t * speed).truncatingRemainder(dividingBy: beatWidth)
                let midY = size.height / 2
                let amp = size.height / 2 * 0.85

                var path = Path()
                var started = false
                let beats = Int(size.width / beatWidth) + 2
                for k in 0..<beats {
                    let baseX = CGFloat(k) * beatWidth - scroll
                    for (nx, ny) in Self.beat {
                        let p = CGPoint(x: baseX + nx * beatWidth, y: midY - ny * amp)
                        if started { path.addLine(to: p) } else { path.move(to: p); started = true }
                    }
                }
                ctx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

#Preview("Enabled") {
    SuspectHoldToAnswerView(bpm: 69, isEnabled: true)
}

#Preview("Disabled (waiting on interrogator)") {
    SuspectHoldToAnswerView(bpm: 69, isEnabled: false)
}
