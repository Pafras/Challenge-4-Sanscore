// SussTypography.swift
// THE design-system type scale (Satria's Figma, SF Pro VARIABLE axes).
// One source of truth — every screen picks a token, never hand-rolls
// size/weight/width again.
//
// Figma table:
//   Large Title / Title 1 / Title 2 / Title 3  -> Width 150, Weight 1000
//                                                (= SF Pro expanded BLACK)
//   Headline                                    -> Expanded Bold
//   Body / Callout / Subhead / Footnote /
//   Caption 1 / Caption 2                       -> Expanded Regular
//
// Everything in the design gets an OUTLINE STROKE -> use SussText (wraps
// IdentityTitle's Core Text stroke renderer) instead of plain Text.
// Plain (unstroked) SwiftUI Text: use Font.suss(.style).
//
// SIZES: Figma-confirmed where noted; the rest follow the HIG ramp — tweak the
// numbers below when Satria publishes the exact px, nothing else changes.
//
// OWNER: Marleen (design system).

import SwiftUI
#if os(iOS)
import UIKit

enum SussTextStyle {
    case displayTitle                       // jumbo screen title (LETS CALIBRATE)
    case largeTitle, title1, title2, title3
    case headline
    // Body scale (Figma): Body 1 = 20, Body 2 = 18. body1Bold for emphasis.
    case body1Bold, body1, body2
    case callout, subhead, footnote, caption1, caption2

    /// Point size per style — the full Figma table.
    var size: CGFloat {
        switch self {
        case .displayTitle: return 44
        case .largeTitle: return 31
        case .title1:     return 25
        case .title2:     return 19
        case .title3:     return 17
        case .headline:   return 14
        case .body1Bold:  return 20
        case .body1:      return 20
        case .body2:      return 18
        case .callout:    return 13
        case .subhead:    return 12
        case .footnote:   return 12
        case .caption1:   return 12   // ALL CAPS (caller uppercases)
        case .caption2:   return 11
        }
    }

    /// Variable-font WEIGHT axis per the Figma table.
    var weight: UIFont.Weight {
        switch self {
        case .displayTitle, .largeTitle, .title1, .title2, .title3: return .black  // Weight 7
        case .headline, .body1Bold:                  return .bold      // Expanded Bold
        case .body1:                                 return .medium    // Body 1 = medium
        case .body2:                                 return .semibold  // Body 2 = semibold
        default:                                     return .regular   // Expanded Regular
        }
    }
    /// WIDTH axis: ONLY titles are Expanded (Width 150). Headline & below =
    /// regular width.
    var width: UIFont.Width {
        switch self {
        case .displayTitle, .largeTitle, .title1, .title2, .title3: return .expanded
        default: return .standard
        }
    }
    var isExpanded: Bool { width == .expanded }

    /// Default outline thickness. ONLY titles get a stroke — headline & below
    /// render plain (white), no outline.
    var strokeWidth: CGFloat {
        switch self {
        case .displayTitle:        return 5
        case .largeTitle, .title1: return 5
        case .title2, .title3:     return 4
        default:                   return 0   // headline, body, caption… = no stroke
        }
    }
}

/// Design-system stroked text: pick a token, get the right axes + outline.
///   SussText("ENTER CODE", style: .largeTitle,
///            fill: Color(hex: "2A1AE8"), stroke: Color(hex: "8FE0FF"))
struct SussText: View {
    let text: String
    var style: SussTextStyle = .body1
    var fill: Color = .white
    var stroke: Color = .black.opacity(0.3)
    var tilt: Double = 0
    /// Override the token's outline thickness when a screen needs to.
    var strokeWidth: CGFloat? = nil
    /// Multiline alignment (default centered, like titles).
    var textAlignment: NSTextAlignment = .center

    var body: some View {
        IdentityTitle(text: text,
                      size: style.size,
                      strokeWidth: strokeWidth ?? style.strokeWidth,
                      fill: fill,
                      stroke: stroke,
                      tilt: tilt,
                      weight: style.weight,
                      width: style.width,
                      textAlignment: textAlignment)
    }
}

extension Font {
    /// Plain (no outline) SwiftUI font with the design-system axes. Width is
    /// BAKED into the Font (.width) — the .fontWidth() view modifier does NOT
    /// reliably override an explicit .system font, so expanded was being lost.
    static func suss(_ style: SussTextStyle) -> Font {
        .system(size: style.size, weight: Font.Weight(style.weight))
            .width(style.isExpanded ? .expanded : .standard)
    }
}

private extension Font.Weight {
    init(_ ui: UIFont.Weight) {
        switch ui {
        case .black:    self = .black
        case .bold:     self = .bold
        case .semibold: self = .semibold
        case .medium:   self = .medium
        default:        self = .regular
        }
    }
}

extension View {
    /// Pair with Font.suss(_:) — applies the design-system Expanded width.
    func sussWidth() -> some View { fontWidth(.expanded) }

    /// One-call plain (unstroked) design-system text: size + weight + Expanded
    /// width (width baked into Font.suss). Use for body/headline/caption.
    ///   Text("Put your pointy finger on the camera").sussFont(.body1)
    func sussFont(_ style: SussTextStyle) -> some View {
        font(.suss(style))
    }
}

#Preview("Type ramp") {
    ScrollView {
        VStack(spacing: 14) {
            SussText(text: "LARGE TITLE", style: .largeTitle, fill: Color(hex: "FF2684"), stroke: .white)
            SussText(text: "TITLE 1", style: .title1, fill: Color(hex: "FF2684"), stroke: .white)
            SussText(text: "TITLE 2", style: .title2, fill: Color(hex: "2A1AE8"), stroke: Color(hex: "8FE0FF"))
            SussText(text: "TITLE 3", style: .title3, fill: Color(hex: "2A1AE8"), stroke: Color(hex: "8FE0FF"))
            Group {
                Text("Headline — 14 Expanded Bold").sussFont(.headline)
                Text("Body 1 Bold — 20").sussFont(.body1Bold)
                Text("Body 1 — 20").sussFont(.body1)
                Text("Body 2 — 18 semibold").sussFont(.body2)
                Text("Footnote — 13").sussFont(.footnote)
                Text("Caption 1 — 12").sussFont(.caption1)
                Text("Caption 2 — 11").sussFont(.caption2)
            }
            .foregroundStyle(.white)
        }
        .padding()
    }
    .background(Color(hex: "1A1A1A"))
}
#endif
