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
        case .neutral: return Color(red: 0.30, green: 0.30, blue: 0.31)
        case .warning: return Color(red: 0.80, green: 0.68, blue: 0.34)
        case .danger:  return Color(red: 0.68, green: 0.35, blue: 0.35)
        case .success: return Color(red: 0.47, green: 0.69, blue: 0.60)
        }
    }
    var bottom: Color {
        switch self {
        case .neutral: return Color(red: 0.18, green: 0.18, blue: 0.19)
        case .warning: return Color(red: 0.71, green: 0.58, blue: 0.25)
        case .danger:  return Color(red: 0.58, green: 0.27, blue: 0.27)
        case .success: return Color(red: 0.37, green: 0.60, blue: 0.51)
        }
    }
}

struct SusToastView: View {
    let toast: Toast
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // 10px white glyph, black 30% stroke 3px (StrokedIcon).
            StrokedIcon(systemName: "info", size: 10,
                        fill: .white, stroke: .black.opacity(0.3), strokeWidth: 3)
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RadialGradient(colors: [toast.style.top, toast.style.bottom],
                                     center: .center, startRadius: 0, endRadius: 160))
                .opacity(0.5)   // background at 50% opacity
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
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
