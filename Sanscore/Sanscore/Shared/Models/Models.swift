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
    var hesitation: Double     // 0-1, share of the answer spent pausing mid-sentence
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

// What the LLM returns after reading the answer text — on the iPhones that have
// one. Both halves are optional extras: the score is folded into the fusion as a
// fifth signal, the verdict replaces the local line.
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

// The four fun buckets the meter shows — one per result screen (Agung's
// VeryTruth / KindaTruth / KindaSus / VerySus). Quartiles of the 0…1 score.
enum SusBand: Equatable {
    case veryTruth   // 0.0  - 0.25
    case kindaTruth  // 0.25 - 0.5
    case kindaSus    // 0.5  - 0.75
    case verySus     // 0.75 - 1.0

    init(score: Double) {
        switch score {
        case ..<0.25: self = .veryTruth
        case ..<0.5:  self = .kindaTruth
        case ..<0.75: self = .kindaSus
        default:      self = .verySus
        }
    }

    var label: String {
        switch self {
        case .veryTruth:  return "Very Truth"
        case .kindaTruth: return "Kinda Truth"
        case .kindaSus:   return "Kinda Sus"
        case .verySus:    return "Very Sus"
        }
    }
}

// Where the game is right now. UI reads this to decide what screen to show.
enum GameState {
    case idle          // create/join room
    case nameEntry     // "what's your name" — after create/join code, before photo
    case identity      // take photo + swipe-down to enter (after name, before lobby)
    case calibrating
    case syncing       // done calibrating, waiting for every device before the reveal (barrier)
    case roomLobby     // connected, waiting for host to hit start
    case roleReveal    // roulette: colours spin like a slot machine
    case roleResult    // lands -> shows this device's role screen (Interrogator/Suspect/Spectator)
    case asking
    case fingerCheck      // answerer only: "put finger on camera" warning before answering
    case answering
    case spectating       // not this round's asker or answerer
    case waitingForResult // asker, after release: waiting on the answerer's phone
    case loading          // answerer only: reading heart rate + transcribing speech
    case calculating      // answerer only: the LLM judges the answer + fuses the score
    case result
}

// Semantic level of a transient toast. Logic-safe (no SwiftUI) so the
// ViewModel can set it; the UI (ToastView) maps each case to its colours.
// Matches Satria's design-system Label variants.
enum ToastStyle {
    case neutral   // info, e.g. "X left the room"
    case warning   // caution
    case danger    // error / round broke
    case success   // good news
}

// A transient banner shown over gameplay. Auto-clears in the ViewModel.
struct Toast: Equatable {
    var message: String
    var style: ToastStyle
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
    var bpm: Int?          // answerer's recorded heart rate this round (nil = unknown)
    var transcript: String?   // what the answerer said (for closed captions)
}

// Everything that travels between phones in a room. One envelope type so
// RoomService has a single send/receive path. Names identify roles — the host
// broadcasts WHO asks/answers, each phone checks its own name, so devices don't
// need a matching player order.
enum RoomMessage: Codable {
    case turn(asker: String, answerer: String)   // host -> all, each round
    case question(String)                        // asker -> answerer
    case calculating                             // answerer -> all: answer done, meter spinning
    case result(RoundResult)                     // answerer -> all
    case profile(name: String, image: Data, colorIndex: Int)   // any -> all: avatar + chosen colour
    case rename(id: String, display: String)     // any -> all: chosen display name
    case joinAccepted                            // host -> joiner: code correct, you're in
    case joinRejected                            // host -> joiner: wrong code, leave
    case roomInfo(title: String)                 // host -> joiner: room title (host's name)
    case inLobby(name: String)                   // any -> all: finished profile setup, show my bubble
    case roster([String])                        // host -> all: authoritative lobby member list
    case ready(name: String)                     // any -> host: done calibrating, ready to reveal
    case beginReveal                             // host -> all: everyone ready, start the reveal NOW
    case readyNext(name: String)                 // any -> all: tapped READY on the result screen
    case caption(String)                         // answerer -> all: live transcript for closed captions
}
