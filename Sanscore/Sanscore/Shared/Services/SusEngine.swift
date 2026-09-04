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
    // Mid-answer pausing. This slot used to hold the LLM's answer-structure
    // score; it was handed to speech timing so that every iPhone can produce
    // all four signals, with or without Apple Intelligence.
    var hesitation: Double = 0.3

    // The four measured weights above always sum to 1.0 — every iPhone can
    // produce all four. This one is different: it is the SHARE the LLM takes
    // when the device has Apple Intelligence, with the measured four scaled
    // down to fit. On a phone without it the four keep the whole 1.0, so the
    // score still uses the full range instead of being nudged by a fake middle
    // value. One knob, and it can never make the weights stop summing to 1.
    var structure: Double = 0.25

    var sum: Double { heartRate + responseTime + speechRate + hesitation }
}

// How big a deviation counts as "maxed out sus" (score 1.0) for each signal.
// e.g. heartRate 0.3 means "a 30% jump from your baseline HR = fully sus".
struct SusSensitivity {
    var heartRate: Double = 0.3
    var responseTime: Double = 1.0   // 2x slower than normal = fully sus
    var speechRate: Double = 0.5

    // Wobble to ignore BEFORE anything counts as suspicious. Camera PPG reads
    // ±10-15 BPM off, so ~8% of a 72 BPM baseline is sensor noise, not nerves.
    // Without this every calm player still picked up heart-rate sus.
    // Response time and speech rate have no sensor noise floor -> 0.
    var heartRateDeadband: Double = 0.08
}

struct SusEngine {
    var weights = SusWeights()
    var sensitivity = SusSensitivity()

    // Which side of the baseline is actually a tell.
    // Answering FASTER than your normal, or a CALMER heart, is not suspicious —
    // if anything it reads as honest — so those signals only count upward.
    // Speech rate stays two-sided: halting AND rushed speech both read nervous.
    enum Deviation { case aboveOnly, both }

    // Turn one raw signal into 0 (normal) ... 1 (very sus), based on how far
    // it deviates from the player's own baseline, ignoring `deadband` of
    // wobble first (sensor noise + normal human variation).
    func normalize(_ value: Double, baseline: Double, sensitivity: Double,
                   deviation: Deviation = .both, deadband: Double = 0) -> Double {
        guard baseline > 0, sensitivity > 0 else { return 0 }
        let signed = (value - baseline) / baseline
        let amount = deviation == .aboveOnly ? max(signed, 0) : abs(signed)
        return min(max(amount - deadband, 0) / sensitivity, 1.0)
    }

    // The whole fusion.
    //
    // `structureScore` is the LLM's reading of the answer's meaning, and is nil
    // on every iPhone without Apple Intelligence. Passing nil is not a penalty:
    // the four measured signals simply keep the full weight between them.
    func score(signals: Signals, baseline: Baseline, structureScore: Double? = nil) -> SusResult {
        let h = normalize(signals.heartRate, baseline: baseline.heartRate, sensitivity: sensitivity.heartRate,
                          deviation: .aboveOnly, deadband: sensitivity.heartRateDeadband)
        let t = normalize(signals.responseTime, baseline: baseline.responseTime, sensitivity: sensitivity.responseTime,
                          deviation: .aboveOnly)
        let s = normalize(signals.speechRate, baseline: baseline.speechRate, sensitivity: sensitivity.speechRate)
        let p = clamp01(signals.hesitation)

        // The measured part is already a full 0-1 score on its own (the four
        // weights sum to 1), which is what makes mixing in the LLM a one-liner.
        let measured = weights.heartRate * h
                     + weights.responseTime * t
                     + weights.speechRate * s
                     + weights.hesitation * p

        let raw: Double
        if let structureScore {
            raw = measured * (1 - weights.structure) + weights.structure * clamp01(structureScore)
        } else {
            raw = measured
        }

        let final = clamp01(raw)
        return SusResult(score: final, band: SusBand(score: final), verdict: "")
    }

    private func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }
}
