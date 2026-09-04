//  WatchHeartRate.swift
//  Heart rate from the paired Apple Watch instead of the camera. Implements the
//  same HeartRateSource protocol as RealHeartRate, so GameViewModel uses it
//  identically — swap RealHeartRate() for WatchHeartRate() and nothing else
//  changes.
//
//  Because the answerer holds the phone, the watch measures HR HANDS-FREE, WHILE
//  they answer — fixing both camera gotchas (finger-on-lens + HR read 8s late).
//
//  Flow: startLiveCapture() tells the watch to begin (WCSession {cmd:start});
//  the watch streams {bpm:Int} back; liveBPM() feeds the on-screen readout;
//  finishLiveCapture() tells the watch to stop and returns the last BPM.
//
//  OWNER: Pafras. iOS-only. The watch half is WatchConnector.swift.
//
//  ponytail: last-value BPM (real HR is already smooth ~1Hz, no smoothing needed
//  like the camera did). Neutral 75 fallback if no watch samples arrived.

#if os(iOS)
import Foundation
import WatchConnectivity
import HealthKit

final class WatchHeartRate: NSObject, HeartRateSource, WCSessionDelegate {

    private var latestBPM: Double?
    private let lock = NSLock()
    private let healthStore = HKHealthStore()

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        // Needed to launch the watch app's workout via startWatchApp(with:).
        if HKHealthStore.isHealthDataAvailable() {
            healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                             read: []) { _, _ in }
        }
    }

    /// True when a watch is paired to this iPhone AND the Sanscore watch app is
    /// installed on it — i.e., we can actually get HR from the wrist. The start
    /// screen uses this to offer "connect your Apple Watch". (isReachable is a
    /// separate, moment-to-moment thing — the watch app being open right now.)
    var isAvailable: Bool {
        WCSession.isSupported()
            && WCSession.default.isPaired
            && WCSession.default.isWatchAppInstalled
    }

    // Non-live path (protocol requirement): run a full capture, return BPM.
    func currentBPM() async -> Double {
        await startLiveCapture()
        try? await Task.sleep(nanoseconds: 8_000_000_000)   // ~8 beats of signal
        return await finishLiveCapture()
    }

    func startLiveCapture() async {
        setLatest(nil)
        // Launch the watch app on the wrist AND start its workout in one call —
        // the player never has to open the watch app. The watch's handle(_:)
        // catches this and begins measuring. If it fails (no watch, denied),
        // fall back to a plain WCSession start in case the app is already open.
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor
        do {
            try await startWatchApp(config)
        } catch {
            print("⌚️ startWatchApp failed (\(error)); falling back to WCSession start")
            send(["cmd": "start"])
        }
    }

    func liveBPM() -> Double? { readLatest() }

    func finishLiveCapture() async -> Double {
        send(["cmd": "stop"])
        return readLatest() ?? 75   // no watch / unreachable → same neutral as RealHeartRate
    }

    // startWatchApp(with:) is completion-based (no async overload) — bridge it.
    private func startWatchApp(_ config: HKWorkoutConfiguration) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            healthStore.startWatchApp(with: config) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    private func send(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // Locked access wrapped in sync helpers — NSLock.lock() is not allowed from
    // an async context (Swift 6), so async callers go through these.
    private func setLatest(_ v: Double?) { lock.lock(); latestBPM = v; lock.unlock() }
    private func readLatest() -> Double? { lock.lock(); defer { lock.unlock() }; return latestBPM }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let bpm = message["bpm"] as? Int else { return }
        setLatest(Double(bpm))
    }
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
#endif
