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
    let baseline = Baseline(heartRate: 72, responseTime: 2.0, speechRate: 2.2)

    // 1) A perfectly calm, direct answer should score near 0 (Truth).
    let calm = Signals(heartRate: 72, responseTime: 2.0, speechRate: 2.2, answerText: "yes")
    let calmResult = engine.score(signals: calm, baseline: baseline, structureScore: 0.0)
    assert(approxEqual(calmResult.score, 0.0), "calm answer should be ~0, got \(calmResult.score)")
    assert(calmResult.band == .truth, "calm answer should land in Truth band")

    // 2) The worked example from the design diagram.
    //    HR 92 (base 72, sens 0.3) -> dev 0.278/0.3 = 0.926
    //    time 4.1 (base 2.0, sens 1.0) -> dev 1.05 -> clamp 1.0
    //    rate 1.6 (base 2.2, sens 0.5) -> dev 0.273/0.5 = 0.545
    //    structure 0.7
    //    score = 0.3*0.926 + 0.2*1.0 + 0.2*0.545 + 0.3*0.7 = 0.797
    let sus = Signals(heartRate: 92, responseTime: 4.1, speechRate: 1.6, answerText: "uh i was home")
    let susResult = engine.score(signals: sus, baseline: baseline, structureScore: 0.7)
    assert(approxEqual(susResult.score, 0.797, tol: 0.005), "worked example expected ~0.797, got \(susResult.score)")
    assert(susResult.band == .liar, "worked example should land in Liar band, got \(susResult.band.label)")

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
