// VerdictLines.swift
// The funny one-liner on the result screen, without the LLM.
//
// Only iPhone 15 Pro and newer have Apple Intelligence, so on every other
// phone StructureAnalyzer cannot run at all. Before this file those players
// saw the same "The judge shrugged." every single round — the payoff line of
// the whole game, repeated forever. Now they get a random line for their band,
// and the LLM is a bonus that writes something sharper when it is available.
//
// OWNER: Pafras. Pure data — add lines freely, they localize automatically.

import Foundation

enum VerdictLines {

    /// A random line to match the band the needle landed on.
    static func random(for band: SusBand) -> String {
        lines(for: band).randomElement() ?? ""
    }

    /// Shown when the mic heard nothing at all — not a verdict, an instruction.
    static var unheard: String {
        String(localized: "Couldn't hear you — say that again louder.", bundle: .app)
    }

    private static func lines(for band: SusBand) -> [String] {
        switch band {
        case .veryTruth:
            return [String(localized: "Suspiciously honest. We'll allow it.", bundle: .app),
                    String(localized: "Not a single crack. Boring, but clean.", bundle: .app),
                    String(localized: "The machine believes you. For now.", bundle: .app)]
        case .kindaTruth:
            return [String(localized: "Mostly solid. One eyebrow raised.", bundle: .app),
                    String(localized: "Nothing to arrest you for. Yet.", bundle: .app),
                    String(localized: "Fine. But you paused, and we noticed.", bundle: .app)]
        case .kindaSus:
            return [String(localized: "That took a suspicious amount of thinking.", bundle: .app),
                    String(localized: "Half a story is still half a story.", bundle: .app),
                    String(localized: "You're sweating a little, aren't you?", bundle: .app)]
        case .verySus:
            return [String(localized: "The needle went all the way. Impressive.", bundle: .app),
                    String(localized: "Even the phone is embarrassed for you.", bundle: .app),
                    String(localized: "Nobody hesitates that much telling the truth.", bundle: .app)]
        }
    }
}
