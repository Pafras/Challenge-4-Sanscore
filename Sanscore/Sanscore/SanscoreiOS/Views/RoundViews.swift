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

struct CalibratingView: View {
    let prompt: String
    let step: Int
    let total: Int
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: prompt,
                       subtitle: "Calibrating \(step) of \(total) — this is your normal",
                       color: .purple,
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

struct CalculatingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Calculating your answer…")
                .font(.title3.bold())
            Text("The judge is thinking…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct ResultView: View {
    let result: SusResult
    var canAdvance: Bool
    var onNext: () -> Void

    private var bandColor: Color {
        switch result.band {
        case .truth: return .green
        case .hmm:   return .yellow
        case .liar:  return .red
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
