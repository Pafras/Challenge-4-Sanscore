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
    private let sampleWindow: Double = 12   // seconds of finger-on-lens

    // Runs a full ~12s capture, then returns the estimated BPM. Falls back to a
    // neutral 75 if the finger wasn't on the lens (too few / flat samples).
    func currentBPM() async -> Double {
        guard await configureAndStart() else { return 75 }
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

        device = cam
        session.beginConfiguration()
        session.sessionPreset = .low   // low res = less work, plenty for average brightness
        if session.canAddInput(input) { session.addInput(input) }
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        // Torch on — the light source PPG needs.
        if cam.hasTorch, (try? cam.lockForConfiguration()) != nil {
            try? cam.setTorchModeOn(level: 1.0)
            cam.unlockForConfiguration()
        }

        samples.removeAll()
        session.startRunning()
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

        // Detrend: subtract a moving mean so we count pulses, not slow drift.
        let values = samples.map { $0.v }
        let mean = values.reduce(0, +) / Double(values.count)
        let centered = values.map { $0 - mean }

        // A flat signal (no finger) has tiny variance -> reject.
        let variance = centered.map { $0 * $0 }.reduce(0, +) / Double(centered.count)
        guard variance > 1.0 else { return nil }

        // Count upward zero-crossings = one per heartbeat.
        var beats = 0
        for i in 1..<centered.count where centered[i - 1] <= 0 && centered[i] > 0 {
            beats += 1
        }
        let elapsed = samples.last!.t - samples.first!.t
        guard elapsed > 0 else { return nil }

        let bpm = Double(beats) / elapsed * 60.0
        // Clamp to a sane human range; garbage outside means bad capture.
        guard (40...200).contains(bpm) else { return nil }
        return bpm
    }
}
#endif
