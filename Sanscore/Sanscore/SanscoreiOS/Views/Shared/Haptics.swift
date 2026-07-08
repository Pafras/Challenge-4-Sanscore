// Haptics.swift
// Small haptic-feedback helper. IMPORTANT: haptics are NO-OPS on the Simulator
// (both UIFeedbackGenerator and Core Haptics) — you only feel them on a real
// device. Fire-and-forget; the generators are cheap to make per call.
//
// ponytail: plain UIFeedbackGenerator (one line each). The BPM-synced heartbeat
// (the signature moment) will need Core Haptics — add it when wiring the HR
// screens on a device.

import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// Accelerating "drumroll" for the sus-meter suspense: soft ticks that speed up
// and harden while the needle sweeps, ended by a heavy SNAP when it locks onto
// the score. Start it while computing, call snap() when the score arrives.
@MainActor
final class TensionHaptic {
    private var task: Task<Void, Never>?

    func start() {
        stop()
        task = Task { @MainActor in
            var interval = 0.42
            while !Task.isCancelled {
                let style: UIImpactFeedbackGenerator.FeedbackStyle =
                    interval > 0.28 ? .soft : (interval > 0.16 ? .medium : .rigid)
                UIImpactFeedbackGenerator(style: style).impactOccurred()
                try? await Task.sleep(for: .seconds(interval))
                interval = max(0.08, interval * 0.88)   // accelerate toward the reveal
            }
        }
    }

    func snap() {
        stop()
        Haptics.impact(.heavy)
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
