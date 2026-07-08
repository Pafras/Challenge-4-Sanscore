//
//  InterrogatorHoldToQuestionView.swift
//  Sanscore
//
//  Created by Agung Ananda on 06/07/26.
//
//  The INTERROGATOR's screen. Two phases on one view:
//    • ASKING   — hold the glass mic to speak the question (waveform while held).
//    • WAITING  — after releasing, "Waiting for Answer" while the suspect answers.
//
//  Reuses MicHoldButton + WaveformBars (defined in SuspectHoldToAnswerView.swift,
//  same module). No BPM here — the interrogator isn't the one being measured.
//
//  Assets used: blue-bg (background), press-hold-to-question (title art),
//  mic-logo (pink mic icon).
//
//  Standalone — not wired into the game flow yet. In the real flow, releasing
//  the mic broadcasts the question and moves everyone forward; here it just
//  switches to the local WAITING phase so you can preview it.
//

import SwiftUI

struct InterrogatorHoldToQuestionView: View {

    private enum Phase { case asking, waiting }

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    private let circleSize: CGFloat = 240
    private let titleWidth: CGFloat = 320
    private let barCount = 9
    // ──────────────────────────────────────────────────────────────────────

    @State private var phase: Phase = .asking
    @State private var isHolding = false

    // ── PUSH-TO-TALK (wire point) ─────────────────────────────────────────
    // Wired in GameFlowView to vm.askerPressed() (start capturing the question)
    // and vm.askerReleased() (transcribe + broadcast, move everyone forward).
    // nil in #Preview, where the local WAITING phase drives the preview.
    private let onPress: (() -> Void)?
    private let onRelease: (() -> Void)?

    /// `previewWaiting: true` opens straight in the WAITING phase (for #Preview).
    init(previewWaiting: Bool = false,
         onPress: (() -> Void)? = nil,
         onRelease: (() -> Void)? = nil) {
        _phase = State(initialValue: previewWaiting ? .waiting : .asking)
        self.onPress = onPress
        self.onRelease = onRelease
    }

    var body: some View {
        ZStack {
            Image("blue-bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            switch phase {
            case .asking:  askingContent
            case .waiting: waitingContent
            }
        }
        .animation(.easeInOut, value: phase)
        // Press the mic = start capturing. Release = done asking -> wait for
        // the answer (locally flips to WAITING; in-flow vm moves the state on).
        .onChange(of: isHolding) { wasHolding, nowHolding in
            if !wasHolding && nowHolding { onPress?() }
            if wasHolding && !nowHolding { phase = .waiting; onRelease?() }
        }
    }

    // MARK: - ASKING

    private var askingContent: some View {
        VStack {
            Image("press-hold-to-question")
                .resizable()
                .scaledToFit()
                .frame(width: titleWidth)
                .padding(.top, 24)
                .offset(y: 60)

            // Hint, hidden once you start talking.
            if !isHolding {
                Text("You'll go first to ask by\nspeaking to the mic.")
                    .sussFont(.body2)              // design system: Body 2 (18 semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 80)
                    .transition(.opacity)
            }

            Spacer()

            MicHoldButton(
                size: circleSize,
                barCount: barCount,
                isEnabled: true,
                isHolding: $isHolding
            )

            Spacer()
            Spacer()   // no BPM row — keep the button vertically centered-ish
        }
        .transition(.opacity)
    }

    // MARK: - WAITING

    private var waitingContent: some View {
        VStack(spacing: 16) {
            Text("Waiting for Answer")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            WaveformBars(barCount: 5)
                .frame(width: 80, height: 34)
        }
        .transition(.opacity)
    }
}

#Preview("Asking") {
    InterrogatorHoldToQuestionView()
}

#Preview("Waiting for answer") {
    InterrogatorHoldToQuestionView(previewWaiting: true)
}
