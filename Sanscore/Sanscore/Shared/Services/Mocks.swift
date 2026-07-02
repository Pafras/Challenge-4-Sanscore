// Mocks.swift
// Fake versions of every capture module. They return fixed numbers so the
// WHOLE game flow runs today with no iPhone, no microphone, no LLM.
// The real modules (camera PPG, SFSpeechRecognizer, Foundation Models)
// implement the same protocols and replace these one by one.

import Foundation

struct MockHeartRate: HeartRateSource {
    var bpm: Double = 92
    // ponytail: real camera PPG isn't instant either; this small delay lets
    // the loading screen actually be visible instead of flashing past.
    func currentBPM() async -> Double {
        try? await Task.sleep(for: .seconds(2))
        return bpm
    }
}

struct MockSpeech: SpeechCapturing {
    var result = SpeechResult(wordCount: 7, duration: 4.4, text: "i was at home the whole night", responseTime: 4.1)
    func startListening() throws {}
    // ponytail: real SFSpeechRecognizer takes a beat to finalize too; see note above.
    func stopAndTranscribe() async -> SpeechResult {
        try? await Task.sleep(for: .seconds(2))
        return result
    }
}

struct MockStructure: StructureAnalyzing {
    var canned = StructureResult(score: 0.7, verdict: "You answered a question with a question.")
    // ponytail: real Foundation Models call takes a beat too; see note above.
    func analyze(question: String, answer: String) async throws -> StructureResult {
        try? await Task.sleep(for: .milliseconds(900))
        return canned
    }
}
