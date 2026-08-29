// StructureAnalyzer.swift
// The real LLM module (Apple Foundation Models, on-device, iOS 26+).
// Reads the answer TEXT and judges its structure: evasive? vague? dodgy?
// Returns a 0-1 score + a funny verdict line.
//
// OWNER: Agung. This is your file. The skeleton + TODOs are below.
// It is wrapped in #if canImport so the rest of the project still compiles
// on machines/simulators without Foundation Models.

#if canImport(FoundationModels)
import FoundationModels

// TODO(agung): add the fields you want the model to score.
// Each @Guide line tells the model what that number means. Keep them 0-1.
@Generable
struct AnswerStructure {
    @Guide(description: "0 = answers directly, 1 = totally dodges the question")
    var evasiveness: Double

    @Guide(description: "0 = clear and specific, 1 = vague or rambling")
    var vagueness: Double

    @Guide(description: "0 = totally confident, 1 = totally timid, shy, or unsure")
    var timidity: Double
    
    @Guide(description: "0 = answers make sense, 1 = inconsistent answers, many self-correction")
    var incoherence: Double
    
    @Guide(description: "one short, funny, playful verdict line for a party game")
    var verdict: String
    
    
}

@available(iOS 26.0, *)
struct StructureAnalyzer: StructureAnalyzing {

    // At or below `honestFloor` the raw score means "normal honest answer" (0);
    // honestFloor + susSpan means "maxed out sus" (1). Tune these from playtests
    // before touching the weights — they move the whole distribution at once.
    private static let honestFloor = 0.35
    private static let susSpan = 0.45

    func analyze(question: String, answer: String) async throws -> StructureResult {
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

        let prompt = """
            Question asked: "\(question)"
            Person answered: "\(answer)"
            Judge the structure of the answer.
            """

        let out = try await session.respond(to: prompt, generating: AnswerStructure.self)
        let s = out.content

        // Dodging the question is the strongest tell; being timid is the weakest
        // (shy honest players were reading as liars), so it counts least.
        let raw = 0.35 * s.evasiveness
                + 0.25 * s.vagueness
                + 0.25 * s.incoherence
                + 0.15 * s.timidity

        // Recentre. All four fields are one-directional "badness" and a language
        // model almost never answers 0 — an honest, casual answer still comes back
        // around 0.4. Raw, that put a permanent floor under every score and made
        // everyone read as a liar. So: drop the floor, stretch what is left.
        let score = min(max((raw - Self.honestFloor) / Self.susSpan, 0), 1)
        return StructureResult(score: score, verdict: s.verdict)
    }
}
#endif
