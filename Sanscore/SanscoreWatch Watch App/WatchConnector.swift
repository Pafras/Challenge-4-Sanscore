//  WatchConnector.swift
//  SanscoreWatch Watch App
//
//  The watch's HR sensor + phone link. It does two jobs:
//    1. Listens to the paired iPhone over WatchConnectivity for {cmd:start/stop}.
//    2. On "start", runs a HealthKit workout session to read LIVE heart rate
//       (~1/sec) and streams each BPM back to the phone as {bpm: Int}.
//
//  The phone side (WatchHeartRate: HeartRateSource) is the ONLY consumer — this
//  file never knows about rooms, turns, or scoring. It just measures + sends.
//
//  OWNER: Pafras (WCSession + HealthKit = async/hardware, lead's job).
//  The UI (WatchRootView) reads `state` + `bpm` and computes nothing.
//
//  Why a workout session just to read HR: Apple Watch only delivers HR at ~1Hz
//  while a workout is running. Without it, samples are sparse/minutes apart. It
//  logs a short "Other" workout to Health — accepted for a party game.
//  ponytail: workout-mode HR. No upgrade path needed for this use.

import Foundation
import SwiftUI
import WatchConnectivity
import HealthKit
import WatchKit

enum WatchMeasureState { case waiting, ready, measuring }

@Observable
final class WatchConnector: NSObject {
    // What the UI reads. Nothing else is public.
    var state: WatchMeasureState = .waiting
    var bpm: Int = 0

    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        requestHealthAuth()
    }

    private func requestHealthAuth() {
        let hr = HKQuantityType(.heartRate)
        health.requestAuthorization(toShare: [], read: [hr]) { _, _ in }
    }

    // MARK: - Start / stop (driven by the phone)

    // Called two ways: WCSession {cmd:start} when the app is already open, OR the
    // WKApplicationDelegate's handle(_:) when the phone LAUNCHED us via
    // startWatchApp(with:) — that hands over a workout config, so use it.
    func startMeasuring(with config: HKWorkoutConfiguration? = nil) {
        guard state != .measuring else { return }
        state = .measuring
        WKInterfaceDevice.current().play(.start)   // haptic tap: "your turn"
        #if targetEnvironment(simulator)
        startFakeBPM()          // sim has no HR sensor
        #else
        startWorkout(config: config)
        #endif
    }

    private func stopMeasuring() {
        #if targetEnvironment(simulator)
        stopFakeBPM()
        #else
        stopWorkout()
        #endif
        state = WCSession.default.isReachable ? .ready : .waiting
    }

    #if DEBUG
    // ponytail: manual trigger so HR can be tested on a real watch WITHOUT the
    // phone driving it. Tap the watch face to start/stop a real HealthKit read.
    // Remove once the phone→watch flow is verified.
    func debugToggleMeasure() {
        if state == .measuring { stopMeasuring() } else { startMeasuring() }
    }
    #endif

    // MARK: - HealthKit workout (real watch)

    private func startWorkout(config providedConfig: HKWorkoutConfiguration? = nil) {
        let config: HKWorkoutConfiguration
        if let providedConfig {
            config = providedConfig            // handed over by the phone's launch
        } else {
            config = HKWorkoutConfiguration()
            config.activityType = .other
            config.locationType = .indoor
        }
        do {
            let session = try HKWorkoutSession(healthStore: health, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: health,
                                                         workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
        } catch {
            print("⌚️ workout start failed: \(error)")
        }
    }

    private func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        session = nil
        builder = nil
    }

    // MARK: - Fake BPM (simulator only, so the flow is demoable without a watch)

    private var fakeTimer: Timer?
    private func startFakeBPM() {
        fakeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let v = Int.random(in: 70...95)
            self?.bpm = v
            self?.sendBPM(v)
        }
    }
    private func stopFakeBPM() { fakeTimer?.invalidate(); fakeTimer = nil }

    // MARK: - Send to phone

    private func sendBPM(_ value: Int) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["bpm": value], replyHandler: nil, errorHandler: nil)
    }

    fileprivate func refreshReachability() {
        guard state != .measuring else { return }   // don't yank the UI mid-measure
        state = WCSession.default.isReachable ? .ready : .waiting
    }
}

// MARK: - Phone link
extension WatchConnector: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.refreshReachability() }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.refreshReachability() }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["cmd"] as? String {
            case "start": self.startMeasuring()
            case "stop":  self.stopMeasuring()
            default:      break
            }
        }
    }
}

// MARK: - HealthKit live HR
extension WatchConnector: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ builder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let hrType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(hrType),
              let stats = builder.statistics(for: hrType),
              let q = stats.mostRecentQuantity() else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let value = Int(q.doubleValue(for: bpmUnit).rounded())
        DispatchQueue.main.async {
            self.bpm = value
            self.sendBPM(value)
        }
    }
    func workoutBuilderDidCollectEvent(_ builder: HKLiveWorkoutBuilder) {}
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("⌚️ workout session error: \(error)")
    }
}
