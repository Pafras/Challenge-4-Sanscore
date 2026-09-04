// SusEngineTests.swift
// A tiny self-check for the brain. No test framework — just asserts, so it
// runs from the command line. Swift only executes top-level code in a file
// named main.swift, so copy this file to main.swift, then compile + run:
//
//     cd TrutOrTruth/Logic
//     cp SusEngineTests.swift main.swift
//     swiftc Models.swift SusEngine.swift main.swift -o /tmp/sustest && /tmp/sustest
//     rm main.swift
//
// (In the real Xcode project this becomes an XCTest case instead.)
//
// If the math breaks, the program crashes on the failing assert. Green = the
// engine still does what we expect. Marleen: when you re-tune weights, run
// this and update the expected numbers to match the new design.

import Foundation

func approxEqual(_ a: Double, _ b: Double, tol: Double = 0.001) -> Bool { abs(a - b) < tol }

func runSusEngineTests() {
    let engine = SusEngine()
    let baseline = Baseline(heartRate: 72, responseTime: 2.0, speechRate: 3.0)

    // 1) A perfectly calm, direct answer should score near 0 (Truth).
    let calm = Signals(heartRate: 72, responseTime: 2.0, speechRate: 3.0, hesitation: 0.0, answerText: "yes")
    let calmResult = engine.score(signals: calm, baseline: baseline)
    assert(approxEqual(calmResult.score, 0.0), "calm answer should be ~0, got \(calmResult.score)")
    assert(calmResult.band == .veryTruth, "calm answer should land in Very Truth band")

    // 2) The worked example from the design diagram.
    //    HR 92 (base 72, sens 0.3, above-only, 0.08 deadband) -> (0.278-0.08)/0.3 = 0.660
    //    time 4.1 (base 2.0, sens 1.0, above-only) -> dev 1.05 -> clamp 1.0
    //    rate 1.6 (base 3.0, sens 0.5) -> dev 0.467/0.5 = 0.933
    //    hesitation 0.9 (long stalls mid-answer), already 0-1
    //    score = 0.3*0.660 + 0.2*1.0 + 0.2*0.933 + 0.3*0.9 = 0.854
    let sus = Signals(heartRate: 92, responseTime: 4.1, speechRate: 1.6, hesitation: 0.9, answerText: "uh i was home")
    let susResult = engine.score(signals: sus, baseline: baseline)
    assert(approxEqual(susResult.score, 0.854, tol: 0.005), "worked example expected ~0.854, got \(susResult.score)")
    assert(susResult.band == .verySus, "worked example should land in Very Sus band, got \(susResult.band.label)")

    // 2b) The bug this tuning fixed: an ordinary honest player (heart rate a few
    //     BPM off from camera jitter, answering fast, normal talking pace, short
    //     casual answer) used to come out "Kinda Sus" (~0.47).
    let honest = Signals(heartRate: 78, responseTime: 1.0, speechRate: 3.1, hesitation: 0.1, answerText: "yeah, i did")
    let honestResult = engine.score(signals: honest, baseline: baseline)
    assert(honestResult.score < 0.25, "honest answer should stay under 0.25, got \(honestResult.score)")
    assert(honestResult.band == .veryTruth, "honest answer should land in Very Truth, got \(honestResult.band.label)")

    // 2c) Answering faster / being calmer than your own baseline is not a tell.
    assert(approxEqual(engine.normalize(1.0, baseline: 2.0, sensitivity: 1.0, deviation: .aboveOnly), 0.0),
           "answering faster than baseline must score 0")
    assert(approxEqual(engine.normalize(76, baseline: 72, sensitivity: 0.3, deviation: .aboveOnly, deadband: 0.08), 0.0),
           "camera jitter must not register as nerves")

    // 2d) With Apple Intelligence the LLM takes a 0.25 share and the measured
    //     four are scaled to fit; without it, nil must leave the score untouched
    //     rather than nudging it toward the middle.
    let withLLM = engine.score(signals: honest, baseline: baseline, structureScore: 1.0)
    assert(approxEqual(withLLM.score, honestResult.score * 0.75 + 0.25, tol: 0.001),
           "structure share should be 0.25, got \(withLLM.score) vs measured \(honestResult.score)")
    assert(approxEqual(engine.score(signals: honest, baseline: baseline, structureScore: nil).score,
                       honestResult.score),
           "nil structure must equal the measured-only score")

    // 3) normalize() must clamp at 1.0 even for huge deviations.
    let huge = engine.normalize(1000, baseline: 72, sensitivity: 0.3)
    assert(approxEqual(huge, 1.0), "normalize should clamp to 1.0, got \(huge)")

    // 4) A zero/invalid baseline must not crash or divide by zero.
    let safe = engine.normalize(92, baseline: 0, sensitivity: 0.3)
    assert(approxEqual(safe, 0.0), "zero baseline should give 0, got \(safe)")

    // 5) Weights sum to 1.0 (sanity: no accidental scaling).
    assert(approxEqual(engine.weights.sum, 1.0), "weights must sum to 1.0, got \(engine.weights.sum)")

    print("All SusEngine tests passed.")
}

runSusEngineTests()
