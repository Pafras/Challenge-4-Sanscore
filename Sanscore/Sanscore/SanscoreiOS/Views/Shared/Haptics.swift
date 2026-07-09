// Haptics.swift
// Small haptic-feedback helper. IMPORTANT: haptics are NO-OPS on the Simulator
// (both UIFeedbackGenerator and Core Haptics) — you only feel them on a real
// device. Fire-and-forget; the generators are cheap to make per call.
//
// ponytail: plain UIFeedbackGenerator (one line each). The BPM-synced heartbeat
// (the signature moment) will need Core Haptics — add it when wiring the HR
// screens on a device.

import UIKit
import CoreHaptics

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

// The signature feel: the phone beats in your hand — a "lub-dub" pulse repeating
// at the player's live BPM while HR is being read (calibration + during the
// answer). Uses Core Haptics for the two-tap beat; falls back to a plain impact
// on devices without it. Simulator = no-op.
@MainActor
final class HeartbeatHaptic {
    private var engine: CHHapticEngine?
    private var task: Task<Void, Never>?
    private var bpm = 75            // updated live via setBPM

    func setBPM(_ value: Int?) {
        if let value { bpm = min(200, max(40, value)) }
    }

    func start(bpm initial: Int?) {
        setBPM(initial)
        prepareEngine()
        task?.cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                beat()
                try? await Task.sleep(for: .seconds(60.0 / Double(bpm)))   // reads latest bpm each beat
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        engine?.stop(completionHandler: nil)
        engine = nil
    }

    private func prepareEngine() {
        guard engine == nil,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    // "lub" (strong) then a softer "dub" ~0.12s later — one heartbeat.
    private func beat() {
        guard let engine else { Haptics.impact(.heavy); return }   // no Core Haptics: single thump
        let lub = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
        ], relativeTime: 0)
        let dub = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
        ], relativeTime: 0.12)
        guard let pattern = try? CHHapticPattern(events: [lub, dub], parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: 0)
    }
}
