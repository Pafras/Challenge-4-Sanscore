// Interfaces.swift
// The contracts. Every capture module promises to fulfill one of these
// protocols. The ViewModel talks ONLY to the protocols, never to a concrete
// class. That is why we can build with mocks today and swap real
// implementations in tomorrow with zero rewrite.

import Foundation

// Heart rate. Today: mock. Later: camera PPG (iPhone) OR Apple Watch.
// Same protocol, so both drop in without touching the ViewModel.
// OWNER: Pafras (camera PPG + Watch are async/hardware = lead's job).
protocol HeartRateSource {
    func currentBPM() async -> Double

    // Live capture: camera runs WHILE the player answers (finger on lens the
    // whole time), so HR is measured during the stress, not 8s after it.
    //   startLiveCapture()  -> begin collecting (called entering .answering)
    //   liveBPM()           -> rolling estimate for the on-screen readout,
    //                          nil until there's enough signal
    //   finishLiveCapture() -> stop + final BPM for scoring
    func startLiveCapture() async
    func liveBPM() -> Double?
    func finishLiveCapture() async -> Double
}

// Defaults so a source without live support (e.g. a future Watch source)
// still works: no live readout, and "finish" falls back to a fresh capture.
extension HeartRateSource {
    func startLiveCapture() async {}
    func liveBPM() -> Double? { nil }
    func finishLiveCapture() async -> Double { await currentBPM() }
}

// What one speech capture produces. rate is computed, not stored.
struct SpeechResult {
    var wordCount: Int
    var duration: Double     // seconds of actual talking (last word end - first word start)
    var text: String         // the full transcript, fed to the LLM
    var responseTime: Double // seconds from "done asking" to first word

    // 0 = spoke straight through, 1 = full of long mid-answer silences.
    // Measured from the gaps BETWEEN words, so it works in any language and
    // needs no model — see RealSpeechCapture.buildResult. This is the signal
    // that replaced the LLM's opinion in the score: every iPhone can produce
    // it, so two players in the same room are judged by the same rules.
    var hesitation: Double = 0

    var speechRate: Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / duration
    }
}

// Records the answer and transcribes it.
// OWNER: Pafras (SFSpeechRecognizer + live audio = async, lead's job).
protocol SpeechCapturing {
    func startListening() throws
    func stopAndTranscribe() async -> SpeechResult
    /// Live partial transcript while listening (for closed captions). nil/"" until speech.
    var liveTranscript: String? { get }
}

// Writes the funny one-line verdict shown on the result screen, by reading the
// question + answer with the on-device LLM. It no longer feeds the SCORE: only
// some iPhones have Apple Intelligence, and a signal half the room cannot
// produce would make the game unfair (see VerdictLines for the fallback).
// OWNER: Agung. See StructureAnalyzer.swift.
protocol StructureAnalyzing {
    /// `band`, `bpm` and `hesitation` are the ALREADY-scored result. They are
    /// passed so the line agrees with the needle and can name something concrete
    /// ("you paused for half the answer"), never so the model can re-score.
    func verdictLine(question: String, answer: String,
                     band: SusBand, bpm: Int, hesitation: Double) async throws -> String
}
