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
    var heartRate: Double = 0.15
    var responseTime: Double = 1.2   // 2.2x slower than normal = fully sus
    var speechRate: Double = 0.30

    // Wobble to ignore BEFORE anything counts as suspicious — sensor noise, not
    // nerves. Kept small: a reading that is pure noise now arrives as nil rather
    // than as a neutral number, so the deadband no longer has to absorb it.
    // Response time and speech rate have no sensor noise floor -> 0.
    var heartRateDeadband: Double = 0.04
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
    // Any signal may be nil, meaning it was never measured — no pulse found, no
    // words heard, no Apple Intelligence on this iPhone. A nil is never a
    // penalty: its weight is shared out among the signals that DID arrive, so
    // the score still spans the full 0-1 range instead of being dragged toward
    // whatever a stand-in value happened to be. Response time is the one signal
    // that is always available, since it is two timestamps.
    func score(signals: Signals, baseline: Baseline, structureScore: Double? = nil) -> SusResult {
        // (weight, 0-1 value) for every signal that actually arrived.
        var parts: [(weight: Double, value: Double)] = []
        if let hr = signals.heartRate {
            parts.append((weights.heartRate,
                          normalize(hr, baseline: baseline.heartRate, sensitivity: sensitivity.heartRate,
                                    deviation: .aboveOnly, deadband: sensitivity.heartRateDeadband)))
        }
        parts.append((weights.responseTime,
                      normalize(signals.responseTime, baseline: baseline.responseTime,
                                sensitivity: sensitivity.responseTime, deviation: .aboveOnly)))
        if let sr = signals.speechRate {
            parts.append((weights.speechRate,
                          normalize(sr, baseline: baseline.speechRate, sensitivity: sensitivity.speechRate)))
        }
        if let hes = signals.hesitation {
            parts.append((weights.hesitation, clamp01(hes)))
        }

        // Weighted average over what arrived, so the measured part is a full 0-1
        // score whether it came from four signals or one. That is also what makes
        // mixing in the LLM a one-liner.
        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let measured = totalWeight > 0
            ? parts.reduce(0) { $0 + $1.weight * $1.value } / totalWeight
            : 0

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
