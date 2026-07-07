// RoundViews.swift
// Screen 6 — all in-round gameplay screens (Figma: "Let's Begin" / "Who's Next"
// role reveal, push-to-talk ask/answer, calibrate, spectate, loading heart-rate
// capture, calculating, and the "SUSS-PECT" result). These are logic-wired to
// the round loop.
//
// OWNER: Pafras. Kept together because they share PushToTalkView and are wired
// to the round state machine. Split further later if it grows.
//
// (The views the root switch calls are module-internal. PushToTalkView stays
// `private` — only used inside this file.)

import SwiftUI
import Combine

struct RoleRevealView: View {
    // Colours cycle like a slot machine while the role is picked.
    private let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .yellow, .red, .mint]
    @State private var idx = 0

    var body: some View {
        colors[idx]
            .ignoresSafeArea()
            .overlay(
                Text("?")
                    .font(.system(size: 140, weight: .black))
                    .foregroundStyle(.white)
            )
            .task {
                // Spin through the palette; slows slightly as it goes (roulette feel).
                var delay = 60
                while true {
                    try? await Task.sleep(for: .milliseconds(delay))
                    idx = (idx + 1) % colors.count
                    if delay < 140 { delay += 6 }   // ease-out the spin
                }
            }
    }
}

// Full-screen push-to-talk. Hold to talk, release fires onRelease.
// enabled = false greys it out and ignores presses (e.g. no question typed yet).
private struct PushToTalkView: View {
    let label: String
    let subtitle: String
    let color: Color
    var enabled: Bool = true
    var onPress: (() -> Void)? = nil
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(isPressed ? .white.opacity(0.8) : .secondary)
                Text(label)
                    .font(.title2.bold())
                    .foregroundStyle(isPressed ? .white : .primary)
                    .multilineTextAlignment(.center)
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isPressed ? .white : color)
            }
            Spacer()
            Text(isPressed ? "Release when done" : "Hold anywhere to talk")
                .font(.caption)
                .foregroundStyle(isPressed ? .white.opacity(0.8) : .secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isPressed ? color : color.opacity(0.12))
        .opacity(enabled ? 1 : 0.4)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard enabled else { return }
                    if !isPressed {
                        isPressed = true
                        onPress?()
                    }
                }
                .onEnded { _ in
                    guard enabled else { return }
                    isPressed = false
                    onRelease()
                }
        )
    }
}

struct AskingView: View {
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: "Ask your question out loud",
                       subtitle: "You're asking",
                       color: .blue,
                       onPress: onPress,
                       onRelease: onRelease)
    }
}

struct AnsweringView: View {
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: "Say your answer",
                       subtitle: "You're answering",
                       color: .green,
                       onPress: onPress,
                       onRelease: onRelease)
    }
}

struct SpectatingView: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Watching this round…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button("Back", action: onCancel)
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .ignoresSafeArea()
    }
}

struct WaitingForResultView: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Waiting for the answer…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Back", action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// ponytail: DEAD — the .loading screen was removed from the flow. HR is now
// captured live during the answer, so runRound goes answering -> .calculating
// (animated sus-meter) with no finger-on-camera countdown. Kept (GameFlowView
// still has a .loading case, now unreachable); delete both when confident.
struct LoadingView: View {
    // Keep in sync with RealHeartRate.sampleWindow.
    private let captureSeconds = 8

    @State private var trim: CGFloat = 1        // ring drains 1 -> 0
    @State private var remaining = 8            // countdown number
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.red.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: trim)
                    .stroke(.red, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))   // start at top
                Text("\(remaining)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .frame(width: 180, height: 180)

            Text("Keep your finger on the back camera")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Cover the rear camera + flash — that's how we read your heartbeat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .onAppear {
            trim = 1
            remaining = captureSeconds
            withAnimation(.linear(duration: Double(captureSeconds))) { trim = 0 }
        }
        .onReceive(tick) { _ in
            if remaining > 0 { withAnimation { remaining -= 1 } }
        }
    }
}

// The suspense "reading" screen: black bg + a drifting lamp glow (same feel as
// LetsBeginView), the 4-colour sus meter on top, "Calculating..." below.
// The needle sweeps while the score is still cooking (targetScore == nil), then
// eases to the REAL score once GameViewModel hands it over — so where it lands
// matches the result the player actually got.
//   score 0.0 = truth  -> needle far RIGHT (green)
//   score 1.0 = liar    -> needle far LEFT  (red)
struct CalculatingView: View {
    /// nil while the LLM/fusion is still running; the real 0...1 score once known.
    var targetScore: Double?

    var body: some View {
        ZStack {
            CalcDriftBackground()
            VStack(spacing: 36) {
                Spacer()
                SusMeter(score: targetScore)
                Text("Calculating...")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Spacer()
            }
            .padding(.bottom, 30)
        }
    }
}

// The gauge: semicircle meter image + the blue teardrop needle pivoting from the
// hub (center of the flat bottom edge). 180° split in four — red / orange /
// yellow / green, left to right.
private struct SusMeter: View {
    var score: Double?

    private let meterW: CGFloat = 300

    // Needle rotation: 0° = straight up. + = clockwise (right/green),
    // - = counter-clockwise (left/red). So (0.5 - score) * 180 maps the score.
    private func angle(for s: Double) -> Double { (0.5 - min(max(s, 0), 1)) * 180 }

    @State private var current: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("suss-meter")
                .resizable()
                .scaledToFit()
                .frame(width: meterW)

            // Base sits at the meter's bottom-center = the gauge hub; we rotate
            // around that base so only the tip swings across the dial.
            Image("suss-arrow")
                .resizable()
                .scaledToFit()
                .frame(height: meterW * 0.46)
                .rotationEffect(.degrees(current), anchor: .bottom)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .frame(width: meterW)
        .task(id: score) { drive() }
    }

    private func drive() {
        if let s = score {
            // Land on the real score. easeInOut = slow start, gentle settle.
            withAnimation(.easeInOut(duration: 1.8)) { current = angle(for: s) }
        } else {
            // Still computing: sweep the whole dial for suspense.
            current = -90
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                current = 90
            }
        }
    }
}

// Dark background with a slow drifting glow — same lamp trick as LetsBeginView.
private struct CalcDriftBackground: View {
    private let cycle: Double = 4.0
    private let lightSize: CGFloat = 460
    private let maxGlow: Double = 0.5

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let size = geo.size
                let t = (timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: cycle)) / cycle
                let pos = CGPoint(x: (0.30 + 0.40 * t) * size.width,
                                  y: (0.40 + 0.15 * t) * size.height)
                let glow = sin(t * .pi) * maxGlow

                ZStack {
                    Image("black-bg")
                        .resizable()
                        .ignoresSafeArea()
                    Circle()
                        .fill(RadialGradient(colors: [.white, .clear],
                                             center: .center,
                                             startRadius: 0,
                                             endRadius: lightSize / 2))
                        .frame(width: lightSize, height: lightSize)
                        .blur(radius: 40)
                        .blendMode(.screen)
                        .position(pos)
                        .opacity(glow)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ResultView: View {
    let result: SusResult
    var canAdvance: Bool
    var onNext: () -> Void

    // ponytail: ResultView is now DEAD — .result renders Agung's per-band
    // screens (VeryTruth/KindaTruth/KindaSus/VerySus) in GameFlowView. Kept
    // only so this file compiles; delete when confident nothing else needs it.
    private var bandColor: Color {
        switch result.band {
        case .veryTruth:  return .green
        case .kindaTruth: return .yellow
        case .kindaSus:   return .orange
        case .verySus:    return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verdict")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(result.band.label)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(bandColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color.green.frame(width: geo.size.width * 0.35)
                        Color.yellow.frame(width: geo.size.width * 0.25)
                        Color.red.frame(width: geo.size.width * 0.40)
                    }
                    .clipShape(Capsule())
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: 18)
                        .offset(x: geo.size.width * result.score - 1)
                }
            }
            .frame(height: 10)

            HStack {
                Text("Truth")
                Spacer()
                Text("Hmm")
                Spacer()
                Text("Liar")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(result.verdict)
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()
            if canAdvance {
                Button("Next round", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Waiting for the host to start the next round…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

#Preview("Calculating (computing)") { CalculatingView(targetScore: nil) }
#Preview("Calculating -> Liar") { CalculatingView(targetScore: 0.85) }
#Preview("Calculating -> Truth") { CalculatingView(targetScore: 0.1) }
