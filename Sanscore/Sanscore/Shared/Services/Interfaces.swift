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
}

// What one speech capture produces. rate is computed, not stored.
struct SpeechResult {
    var wordCount: Int
    var duration: Double     // seconds of actual talking (last word end - first word start)
    var text: String         // the full transcript, fed to the LLM
    var responseTime: Double // seconds from "done asking" to first word

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
}

// Judges the MEANING/STRUCTURE of the answer text with the LLM.
// OWNER: Agung. See StructureAnalyzer.swift for the skeleton to fill.
protocol StructureAnalyzing {
    func analyze(question: String, answer: String) async throws -> StructureResult
}
