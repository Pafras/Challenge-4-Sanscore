// ClosedCaptionView.swift
// Closed captions of the spoken answer — an accessibility feature for deaf /
// hard-of-hearing players. Shows the transcript ONLY when the user has
// "Closed Captions + SDH" turned on in Settings › Accessibility › Subtitles &
// Captioning. That system-driven toggle is what makes it a real "closed"
// caption (user-controlled), so it counts as an a11y feature — unlike dark mode.
//
// To demo: Settings › Accessibility › Subtitles & Captioning › Closed Captions
// + SDH = ON, then finish a round — the answer appears captioned.

import SwiftUI
import UIKit

struct ClosedCaptionView: View {
    let text: String?
    @State private var ccEnabled = UIAccessibility.isClosedCaptioningEnabled
    // In-app Settings toggle — captions show when EITHER the iOS a11y setting
    // OR the app's own CLOSE CAPTIONS switch is on.
    @AppStorage("settings.closedCaptions") private var appCC = false

    var body: some View {
        Group {
            if ccEnabled || appCC, let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .accessibilityLabel("They said: \(text)")
                    .transition(.opacity)
            }
        }
        // Live-update if the user flips the setting while the app is open.
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.closedCaptioningStatusDidChangeNotification)) { _ in
            ccEnabled = UIAccessibility.isClosedCaptioningEnabled
        }
    }
}
