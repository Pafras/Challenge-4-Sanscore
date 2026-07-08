// ToastView.swift
// The design-system "Label" toast (Satria's Figma). One pill, four semantic
// styles: neutral / warning / danger / success. Info glyph on the left, bold
// text in the middle, an X to dismiss on the right.
//
// Logic-free: it only reads a `Toast` (message + style) and calls `onClose`.
// The semantic `ToastStyle` lives in Models.swift so the ViewModel (which must
// not import SwiftUI) can pick a style; this file maps each case to colours.
//
// OWNER: Marleen (UI).

import SwiftUI

// Colour recipe per semantic style. Vertical gradient (lighter top → darker
// bottom) + a soft light rim, matching the design-system Label frame.
private extension ToastStyle {
    var top: Color {
        switch self {
        case .neutral: return Color(hex: "3F3F3F")
        case .warning: return Color(hex: "FFB20B")
        case .danger:  return Color(hex: "C41D20")
        case .success: return Color(hex: "4FE7C8")
        }
    }
    var bottom: Color {
        switch self {
        case .neutral: return Color(hex: "000000")
        case .warning: return Color(hex: "B77D00")
        case .danger:  return Color(hex: "670002")
        case .success: return Color(hex: "017451")
        }
    }
}

struct SusToastView: View {
    let toast: Toast
    /// Left glyph. Default "info"; pass e.g. "exclamationmark" for errors.
    var icon: String = "info"
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // 10px white glyph, black 30% stroke 3px (StrokedIcon).
            StrokedIcon(systemName: icon, size: 10,
                        fill: .white, stroke: .black.opacity(0.3), strokeWidth: 3)
            // title/headline: 14px Expanded Bold, white.
            Text(toast.message)
                .font(.suss(.headline))   // design-system token: 14 Expanded Bold
                .sussWidth()
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let onClose {
                Spacer(minLength: 4)
                Button(action: onClose) {
                    StrokedIcon(systemName: "xmark", size: 10,
                                fill: .white, stroke: .black.opacity(0.3), strokeWidth: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            // Frosted glass (Figma: background blur 40) UNDER the 50% gradient.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    // One gradient layer at 60% — vivid hexes carry the colour,
                    // the material blur stays visible through it.
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(RadialGradient(colors: [toast.style.top, toast.style.bottom],
                                             center: .center, startRadius: 0, endRadius: 160))
                        .opacity(0.6)
                }
        }
        .overlay(
            // Inside stroke: white 60%, 3px.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.6), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }
}

#Preview {
    VStack(spacing: 16) {
        SusToastView(toast: Toast(message: "The Host has ended the game", style: .neutral), onClose: {})
        SusToastView(toast: Toast(message: "The Host has ended the game", style: .warning), onClose: {})
        SusToastView(toast: Toast(message: "The Host has ended the game", style: .danger), onClose: {})
        SusToastView(toast: Toast(message: "The Host has ended the game", style: .success), onClose: {})
    }
    .padding()
    .background(Color.gray)
}
