// RealSpeechCapture.swift
// The real speech module. Records the answer from the mic, transcribes it
// on-device with SFSpeechRecognizer (English), and returns:
//   - text        -> fed to the LLM
//   - wordCount + duration -> speech rate (words / sec)
//   - responseTime -> gap from "done asking" to the FIRST word
//
// Implements the SpeechCapturing protocol, so GameViewModel uses it exactly
// like MockSpeech — swap MockSpeech() for RealSpeechCapture() and nothing else
// changes.
//
// OWNER: Pafras. iOS-only (Speech + AVFoundation). Needs a real iPhone + mic.
//
// Info.plist required:
//   NSMicrophoneUsageDescription
//   NSSpeechRecognitionUsageDescription

#if canImport(Speech)
import Foundation
import Speech
import AVFoundation

enum SpeechError: Error {
    case notAuthorized
    case recognizerUnavailable
    case audioSessionFailed
}

final class RealSpeechCapture: SpeechCapturing {

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // t0 = the moment the asker tapped "done asking". Set in startListening().
    private var startTime: Date?
    // The best transcription we have seen so far.
    private var latest: SFTranscription?

    // Ask permission once, up front. Call this before the first round (e.g. on
    // the calibration screen). Returns true if both mic + speech are granted.
    static func requestPermission() async -> Bool {
        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return speechOK && micOK
    }

    func startListening() throws {
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.recognizerUnavailable }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { throw SpeechError.audioSessionFailed }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true   // private + offline
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        // Keep the newest transcription; we read it when we stop.
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            if let result { self?.latest = result.bestTranscription }
        }

        audioEngine.prepare()
        try audioEngine.start()
        startTime = Date()   // t0
    }

    func stopAndTranscribe() async -> SpeechResult {
        // Stop feeding audio and end the request.
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()

        // ponytail: give the recognizer a short beat to emit its final result
        // before we read `latest`. Good enough for a party game; if words get
        // cut off, switch to waiting for result.isFinal via a continuation.
        try? await Task.sleep(nanoseconds: 300_000_000)

        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        return buildResult(from: latest)
    }

    private func buildResult(from t: SFTranscription?) -> SpeechResult {
        let t0 = startTime ?? Date()
        guard let t, let first = t.segments.first, let last = t.segments.last else {
            // Nothing heard. ViewModel handles empty text as "say it again".
            return SpeechResult(wordCount: 0, duration: 0, text: "", responseTime: 0)
        }
        // Segment timestamps are seconds from the start of audio (t0).
        let responseTime = first.timestamp
        let talkStart = first.timestamp
        let talkEnd = last.timestamp + last.duration
        let duration = max(talkEnd - talkStart, 0.01)   // avoid divide-by-zero
        return SpeechResult(wordCount: t.segments.count,
                            duration: duration,
                            text: t.formattedString,
                            responseTime: responseTime)
    }
}
#endif
