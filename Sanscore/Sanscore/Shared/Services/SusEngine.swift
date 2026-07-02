// SusEngine.swift
// The brain. Takes the 4 signals + the LLM structure score and fuses them
// into ONE sus score (0-1). Pure math, no hardware, no async. This is the
// contract every other module feeds into.
//
// OWNER: Pafras (reference implementation).
// TODO(marleen): after playtesting, tune `weights` and `sensitivity` so the
// meter feels fair and fun. The numbers below are first guesses, not final.
// Change them, run the tests, watch how the example scores move.

import Foundation

// How much each signal counts toward the final score. Must sum to 1.0.
struct SusWeights {
    var heartRate: Double = 0.3
    var responseTime: Double = 0.2
    var speechRate: Double = 0.2
    var structure: Double = 0.3   // the LLM's answer-structure score

    var sum: Double { heartRate + responseTime + speechRate + structure }
}

// How big a deviation counts as "maxed out sus" (score 1.0) for each signal.
// e.g. heartRate 0.3 means "a 30% jump from your baseline HR = fully sus".
struct SusSensitivity {
    var heartRate: Double = 0.3
    var responseTime: Double = 1.0   // 2x slower than normal = fully sus
    var speechRate: Double = 0.5
}

struct SusEngine {
    var weights = SusWeights()
    var sensitivity = SusSensitivity()

    // Turn one raw signal into 0 (normal) ... 1 (very sus), based on how far
    // it deviates from the player's own baseline. abs() means BOTH too-high
    // and too-low count as suspicious (slow AND rushed answers look sus).
    func normalize(_ value: Double, baseline: Double, sensitivity: Double) -> Double {
        guard baseline > 0, sensitivity > 0 else { return 0 }
        let deviation = abs(value - baseline) / baseline
        return min(deviation / sensitivity, 1.0)
    }

    // The whole fusion. structureScore already comes 0-1 from the LLM.
    func score(signals: Signals, baseline: Baseline, structureScore: Double) -> SusResult {
        let h = normalize(signals.heartRate, baseline: baseline.heartRate, sensitivity: sensitivity.heartRate)
        let t = normalize(signals.responseTime, baseline: baseline.responseTime, sensitivity: sensitivity.responseTime)
        let s = normalize(signals.speechRate, baseline: baseline.speechRate, sensitivity: sensitivity.speechRate)
        let st = clamp01(structureScore)

        let raw = weights.heartRate * h
                + weights.responseTime * t
                + weights.speechRate * s
                + weights.structure * st

        let final = clamp01(raw)
        return SusResult(score: final, band: SusBand(score: final), verdict: "")
    }

    private func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }
}
