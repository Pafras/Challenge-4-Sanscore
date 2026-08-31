// StructureAnalyzer.swift
// The real LLM module (Apple Foundation Models, on-device, iOS 26+).
// Reads the answer TEXT and writes the funny verdict line for the result screen.
//
// It no longer contributes to the SCORE. Foundation Models needs Apple
// Intelligence, which only exists on iPhone 15 Pro and newer — so in one room
// some players would be judged on four signals and the rest on three, which is
// not a fair party game. Speech timing (SpeechResult.hesitation) took over that
// slot for everyone; writing something funny is the job only the LLM can do.
//
// OWNER: Agung. This is your file. The skeleton + TODOs are below.
// It is wrapped in #if canImport so the rest of the project still compiles
// on machines/simulators without Foundation Models.

#if canImport(FoundationModels)
import FoundationModels

// The model still scores these four dimensions — not because we use the
// numbers, but because judging the answer before writing the line produces a
// sharper, more specific verdict than asking for a joke straight away.
// Each @Guide line tells the model what that number means. Keep them 0-1.
@Generable
struct AnswerStructure {
    @Guide(description: "0 = answers directly, 1 = totally dodges the question")
    var evasiveness: Double

    @Guide(description: "0 = clear and specific, 1 = vague or rambling")
    var vagueness: Double

    @Guide(description: "0 = says just enough, 1 = over-explains, piles on unrequested detail or alibi")
    var overExplaining: Double
    
    @Guide(description: "0 = answers make sense, 1 = inconsistent answers, many self-correction")
    var incoherence: Double
    
    @Guide(description: "the single most notable thing about HOW they answered, as a short phrase, e.g. 'answered a question with a question' or 'gave a suspiciously exact time'")
    var tell: String

    @Guide(description: "one short, funny, playful verdict line for a party game")
    var verdict: String
    
    
}

@available(iOS 26.0, *)
struct StructureAnalyzer: StructureAnalyzing {

    /// False on every iPhone without Apple Intelligence, when the user has it
    /// switched off, or while the model is still downloading. Checked once at
    /// startup so we never build a session that is only going to throw.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Why the LLM is missing, in the only terms worth showing a player: is this
    /// something they can fix, or not? An unsupported iPhone gets told nothing —
    /// there is nothing they could do about it, and the game plays fine anyway.
    enum Status { case available, offInSettings, stillDownloading, unsupported }

    static var status: Status {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .offInSettings
        case .unavailable(.modelNotReady): return .stillDownloading
        case .unavailable: return .unsupported
        }
    }

    func verdictLine(question: String, answer: String,
                     band: SusBand, bpm: Int, hesitation: Double) async throws -> String {
        // TODO(agung): tune this persona + prompt. Playtest the wording.
        let session = LanguageModelSession(instructions: """
            You are a playful party-game lie detector. You judge only the STRUCTURE
            of an answer (is it evasive, vague, confident, coherent), never whether it is factually
            true. Be fun, not mean. Stay consistent.

            Most answers in this game are honest, casual and SHORT. A short, plain,
            direct answer is neither evasive nor vague — score it near 0. Being shy,
            quiet or softly spoken is not lying. Only score above 0.6 when the person
            genuinely dodges the question, contradicts themselves, or rambles without
            ever answering it. Use the full 0-1 range; do not park everything in the middle.
            """)

        // The measured facts are given to the model as MATERIAL for the line, not
        // as things to score — the numbers were already fused by SusEngine.
        let prompt = """
            Question asked: "\(question)"
            Person answered: "\(answer)"

            The meter landed on: \(band.label.uppercased())
            Their heart rate was \(bpm) BPM.
            They spent \(Int(hesitation * 100))% of the answer pausing mid-sentence.

            Judge the structure of the answer, then write one line that fits the meter.
            """

        let out = try await session.respond(to: prompt, generating: AnswerStructure.self)
        return out.content.verdict
    }
}
#endif
