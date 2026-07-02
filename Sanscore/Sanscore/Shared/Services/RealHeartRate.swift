// RealHeartRate.swift
// Heart rate from the phone camera (photoplethysmography / PPG). The player
// presses a fingertip over the back camera + flashlight; the blood pulsing
// under the skin changes how much red light bounces back each frame. We read
// the average red brightness per frame, then count the pulses.
//
// Implements HeartRateSource, so GameViewModel uses it exactly like
// MockHeartRate — swap MockHeartRate() for RealHeartRate() and nothing else
// changes.
//
// OWNER: Pafras. iOS-only (camera + torch). Needs a real iPhone.
//
// Info.plist required: NSCameraUsageDescription
//
// ponytail: peak-counting on a detrended brightness signal. Good enough for a
// party game (± a few BPM). If you need clinical accuracy, upgrade to bandpass
// filter + FFT — but you don't, so don't.

#if os(iOS)
import Foundation
import AVFoundation

final class RealHeartRate: NSObject, HeartRateSource, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "ppg.camera")
    private var device: AVCaptureDevice?

    // (timestamp seconds, average red brightness) collected while a finger is on.
    private var samples: [(t: Double, v: Double)] = []
    // ponytail: 8s ~ 8-13 beats, good party-game accuracy (±few BPM). Shorter =
    // snappier but coarser; longer = more accurate. Don't go below ~5s.
    // NOTE: keep this in sync with LoadingView's countdown ring (captureSeconds).
    private let sampleWindow: Double = 8   // seconds of finger-on-lens

    // Runs a full ~12s capture, then returns the estimated BPM. Falls back to a
    // neutral 75 if the finger wasn't on the lens (too few / flat samples).
    func currentBPM() async -> Double {
        guard await configureAndStart() else {
            print("❤️‍🩹 HR: camera failed to start (configureAndStart false)")
            return 75
        }
        try? await Task.sleep(nanoseconds: UInt64(sampleWindow * 1_000_000_000))
        stop()
        return estimateBPM() ?? 75
    }

    // MARK: - Camera setup

    private func configureAndStart() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted,
              let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam) else { return false }

        // The mic (RealSpeechCapture) leaves the shared AVAudioSession active in
        // .record/.measurement mode; that can block the camera from starting
        // (FigCaptureSourceRemote err -17281). Release it before capturing.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        device = cam
        session.beginConfiguration()
        // We only capture video. Stop the camera from reconfiguring the shared
        // AVAudioSession — the mic (RealSpeechCapture) leaves it in .record /
        // .measurement mode, and the camera's auto-reconfig clashed with it,
        // failing capture with FigCaptureSourceRemote err -17281 (no frames ->
        // BPM fell back to 75).
        session.automaticallyConfiguresApplicationAudioSession = false
        session.sessionPreset = .low   // low res = less work, plenty for average brightness
        if session.canAddInput(input) { session.addInput(input) }
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        // Force 30fps — the default (~15fps) is too coarse for reliable
        // zero-crossing beat counting. More frames = smoother pulse signal.
        if (try? cam.lockForConfiguration()) != nil {
            let target = CMTime(value: 1, timescale: 30)
            if cam.activeFormat.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= 30 && 30 <= $0.maxFrameRate
            }) {
                cam.activeVideoMinFrameDuration = target
                cam.activeVideoMaxFrameDuration = target
            }
            cam.unlockForConfiguration()
        }

        samples.removeAll()
        // startRunning blocks — keep it off the main thread.
        await withCheckedContinuation { cont in
            queue.async {
                self.session.startRunning()
                cont.resume()
            }
        }

        // Torch on AFTER the session runs — the light source PPG needs.
        if cam.hasTorch, (try? cam.lockForConfiguration()) != nil {
            try? cam.setTorchModeOn(level: 1.0)
            cam.unlockForConfiguration()
        }
        return true
    }

    private func stop() {
        session.stopRunning()
        if let cam = device, cam.hasTorch, (try? cam.lockForConfiguration()) != nil {
            cam.torchMode = .off
            cam.unlockForConfiguration()
        }
    }

    // MARK: - Per-frame red brightness

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixel, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixel) else { return }
        let width = CVPixelBufferGetWidth(pixel)
        let height = CVPixelBufferGetHeight(pixel)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixel)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        // Average the red channel over a sparse grid of pixels (BGRA: red = byte 2).
        var total = 0, count = 0
        let step = 8
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                total += Int(ptr[y * bytesPerRow + x * 4 + 2])
                count += 1
                x += step
            }
            y += step
        }
        guard count > 0 else { return }

        let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let redAvg = Double(total) / Double(count)
        queue.async { self.samples.append((t: t, v: redAvg)) }
    }

    // MARK: - BPM estimate

    private func estimateBPM() -> Double? {
        guard samples.count > 30 else { return nil }   // finger probably wasn't on

        let values = samples.map { $0.v }
        let elapsed = samples.last!.t - samples.first!.t
        guard elapsed > 0 else { return nil }

        // High-pass detrend: subtract a MOVING average, not the global mean.
        // The pulse is a small ripple riding on a large, slowly drifting DC
        // level (finger pressure, torch warmup). Subtracting the global mean
        // leaves that drift, so the ripple rarely crosses zero -> beats badly
        // undercounted. A moving-average window ~1s removes the drift and keeps
        // the pulse, so zero-crossings land on real beats.
        let fps = Double(values.count) / elapsed
        // Window must be LONGER than one pulse period (~0.7s) so the moving
        // average captures only the slow drift, leaving the pulse intact. 1s
        // sat on the pulse frequency and attenuated it; use ~2s.
        let window = max(5, Int(fps * 2))
        var centered = [Double](repeating: 0, count: values.count)
        for i in values.indices {
            let lo = max(0, i - window / 2)
            let hi = min(values.count - 1, i + window / 2)
            var sum = 0.0
            for j in lo...hi { sum += values[j] }
            centered[i] = values[i] - sum / Double(hi - lo + 1)
        }

        // Amplitude of the ripple; a flat signal (no finger) is tiny -> reject.
        let amplitude = (centered.map { $0 * $0 }.reduce(0, +) / Double(centered.count)).squareRoot()

        // Plain upward zero-crossings = one per heartbeat.
        var beats = 0
        for i in 1..<centered.count where centered[i - 1] <= 0 && centered[i] > 0 {
            beats += 1
        }

        let bpm = Double(beats) / elapsed * 60.0

        guard amplitude > 0.3 else { return nil }
        guard (40...200).contains(bpm) else { return nil }
        return bpm
    }
}
#endif
