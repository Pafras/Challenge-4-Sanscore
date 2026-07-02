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
    let baseline = Baseline(heartRate: 72, responseTime: 2.0, speechRate: 2.2)

    func testCalmAnswerIsTruth() {
        let calm = Signals(heartRate: 72, responseTime: 2.0, speechRate: 2.2, answerText: "yes")
        let r = engine.score(signals: calm, baseline: baseline, structureScore: 0.0)
        XCTAssertEqual(r.score, 0.0, accuracy: 0.001)
        XCTAssertEqual(r.band, .truth)
    }

    func testWorkedExampleIsLiar() {
        let sus = Signals(heartRate: 92, responseTime: 4.1, speechRate: 1.6, answerText: "uh i was home")
        let r = engine.score(signals: sus, baseline: baseline, structureScore: 0.7)
        XCTAssertEqual(r.score, 0.797, accuracy: 0.005)
        XCTAssertEqual(r.band, .liar)
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
