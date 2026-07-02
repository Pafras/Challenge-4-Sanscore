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

    @Guide(description: "one short, funny, playful verdict line for a party game")
    var verdict: String
}

@available(iOS 26.0, *)
struct StructureAnalyzer: StructureAnalyzing {

    func analyze(question: String, answer: String) async throws -> StructureResult {
        // TODO(agung): tune this persona + prompt. Playtest the wording.
        let session = LanguageModelSession(instructions: """
            You are a playful party-game lie detector. You judge only the STRUCTURE
            of an answer (is it evasive, vague, dodgy?), never whether it is factually
            true. Be fun, not mean. Stay consistent.
            """)

        let prompt = """
            Question asked: "\(question)"
            Person answered: "\(answer)"
            Judge the structure of the answer.
            """

        let out = try await session.respond(to: prompt, generating: AnswerStructure.self)
        let s = out.content

        // TODO(agung): decide how to combine the fields into one 0-1 score.
        // First guess: weight evasiveness more than vagueness.
        let score = min(max(0.6 * s.evasiveness + 0.4 * s.vagueness, 0), 1)
        return StructureResult(score: score, verdict: s.verdict)
    }
}
#endif
