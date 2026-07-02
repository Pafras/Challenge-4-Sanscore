// Models.swift
// Plain data types shared across the whole app. No UIKit, no SwiftUI, no
// hardware. Pure Swift so it compiles + tests on any machine (even the
// command line), and so beginners can read it without framework noise.

import Foundation

// The raw signals captured during one answer, in their natural units.
// These are NOT yet 0-1. SusEngine normalizes them.
struct Signals {
    var heartRate: Double      // beats per minute, e.g. 92
    var responseTime: Double   // seconds from "done asking" to first word, e.g. 4.1
    var speechRate: Double     // words per second, e.g. 1.6
    var answerText: String     // what SFSpeechRecognizer transcribed
}

// Each player's "normal", captured in the calibration round (easy questions).
// We score how far a signal deviates from THIS, not from an absolute number,
// because everyone's normal is different.
struct Baseline {
    var heartRate: Double
    var responseTime: Double
    var speechRate: Double
}

// What the LLM (Foundation Models) returns after reading the answer text.
struct StructureResult {
    var score: Double     // 0 = direct/honest structure, 1 = very evasive
    var verdict: String   // one funny line to show on the result screen
}

// The final output the UI shows.
struct SusResult {
    var score: Double     // 0.0 (truth) ... 1.0 (liar)
    var band: SusBand
    var verdict: String
}

// The three fun buckets the meter shows.
enum SusBand: Equatable {
    case truth   // 0.0 - 0.35
    case hmm     // 0.35 - 0.6
    case liar    // 0.6 - 1.0

    init(score: Double) {
        switch score {
        case ..<0.35: self = .truth
        case ..<0.6:  self = .hmm
        default:      self = .liar
        }
    }

    var label: String {
        switch self {
        case .truth: return "Truth"
        case .hmm:   return "Hmm"
        case .liar:  return "Liar"
        }
    }
}

// Where the game is right now. UI reads this to decide what screen to show.
enum GameState {
    case idle          // create/join room
    case calibrating
    case roomLobby     // connected, waiting for host to hit start
    case roleReveal    // roulette animation assigning this device's role
    case asking
    case answering
    case spectating       // not this round's asker or answerer
    case waitingForResult // asker, after release: waiting on the answerer's phone
    case loading          // answerer only: reading heart rate + transcribing speech
    case calculating      // answerer only: the LLM judges the answer + fuses the score
    case result
}

// What this device is doing in the current round. Only one device per room
// is .asker and one is .answerer; everyone else is .spectator.
enum PlayerRole {
    case asker
    case answerer
    case spectator
}

// The tiny message sent between phones in a room. Only the RESULT travels the
// network — never raw heart rate or voice. Codable so it turns into JSON.
struct RoundResult: Codable {
    var answererName: String
    var score: Double
    var verdict: String
}

// Everything that travels between phones in a room. One envelope type so
// RoomService has a single send/receive path. Names identify roles — the host
// broadcasts WHO asks/answers, each phone checks its own name, so devices don't
// need a matching player order.
enum RoomMessage: Codable {
    case turn(asker: String, answerer: String)   // host -> all, each round
    case question(String)                        // asker -> answerer
    case result(RoundResult)                     // answerer -> all
}
