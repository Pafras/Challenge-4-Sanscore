// SusEngineXCTests.swift
// The Xcode version of the engine self-check. Add a "Unit Testing Bundle"
// target in Xcode, put this file in it, then Cmd+U to run.
//
// (SusEngineTests.swift in this folder is the command-line version for running
// before the Xcode project exists — same assertions, different harness.)
//
// OWNER: Marleen keeps these green when tuning the weights.

import XCTest
@testable import Sanscore   // change if your app module name differs

final class SusEngineXCTests: XCTestCase {

    let engine = SusEngine()
    let baseline = Baseline(heartRate: 72, responseTime: 2.0, speechRate: 3.0)

    func testCalmAnswerIsTruth() {
        let calm = Signals(heartRate: 72, responseTime: 2.0, speechRate: 3.0, answerText: "yes")
        let r = engine.score(signals: calm, baseline: baseline, structureScore: 0.0)
        XCTAssertEqual(r.score, 0.0, accuracy: 0.001)
        XCTAssertEqual(r.band, .veryTruth)
    }

    func testWorkedExampleIsLiar() {
        let sus = Signals(heartRate: 92, responseTime: 4.1, speechRate: 1.6, answerText: "uh i was home")
        let r = engine.score(signals: sus, baseline: baseline, structureScore: 0.78)
        XCTAssertEqual(r.score, 0.818, accuracy: 0.005)
        XCTAssertEqual(r.band, .verySus)
    }

    // The bug this tuning fixed: an ordinary honest player — heart rate a few
    // BPM off from camera jitter, answering FAST, talking at a normal pace,
    // giving a short casual answer — used to come out "Kinda Sus" (~0.47).
    func testTypicalHonestAnswerReadsAsTruth() {
        let honest = Signals(heartRate: 78, responseTime: 1.0, speechRate: 3.1, answerText: "yeah, i did")
        let r = engine.score(signals: honest, baseline: baseline, structureScore: 0.22)
        XCTAssertLessThan(r.score, 0.25)
        XCTAssertEqual(r.band, .veryTruth)
    }

    // Answering faster / being calmer than your own baseline is not a tell.
    func testFasterThanBaselineIsNotSuspicious() {
        XCTAssertEqual(engine.normalize(1.0, baseline: 2.0, sensitivity: 1.0, deviation: .aboveOnly), 0.0, accuracy: 0.001)
        XCTAssertEqual(engine.normalize(60, baseline: 72, sensitivity: 0.3, deviation: .aboveOnly), 0.0, accuracy: 0.001)
    }

    // Camera-PPG jitter (a few BPM) must not register as nerves.
    func testHeartRateJitterIsIgnored() {
        let r = engine.normalize(76, baseline: 72, sensitivity: 0.3,
                                 deviation: .aboveOnly, deadband: 0.08)
        XCTAssertEqual(r, 0.0, accuracy: 0.001)
    }

    func testNormalizeClampsToOne() {
        XCTAssertEqual(engine.normalize(1000, baseline: 72, sensitivity: 0.3), 1.0, accuracy: 0.001)
    }

    func testZeroBaselineIsSafe() {
        XCTAssertEqual(engine.normalize(92, baseline: 0, sensitivity: 0.3), 0.0, accuracy: 0.001)
    }

    func testWeightsSumToOne() {
        XCTAssertEqual(engine.weights.sum, 1.0, accuracy: 0.001)
    }
}
