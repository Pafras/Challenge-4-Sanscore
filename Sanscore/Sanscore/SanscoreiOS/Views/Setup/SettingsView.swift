// SettingsView.swift
// The SETTINGS drawer (Figma "Settings"): opened from the gear action button on
// the homepage. A full-height drawer sheet (pink-bg, rounded top, close X):
//   • LANGUAGE  — EN / ID segmented toggle (persisted; real localization TODO)
//   • SFX       — volume slider (persisted; audio TODO)
//   • BGM       — volume slider (persisted; audio TODO)
//   • CLOSE CAPTIONS — toggle (persisted; Pafras wires the actual captions)
//
// Persistence only for now — @AppStorage keeps each choice across launches.
// Wiring points are marked TODO. LAYOUT + storage only; no game logic here.
//
// OWNER: Marleen (design system).

import SwiftUI
#if os(iOS)

struct SettingsView: View {
    var onClose: () -> Void

    // Persisted settings. Other views can read the same @AppStorage keys.
    @AppStorage("settings.language")  private var language = "EN"       // "EN" / "ID"
    @AppStorage("settings.sfxVolume") private var sfxVolume  = 0.7
    @AppStorage("settings.bgmVolume") private var bgmVolume  = 0.6
    @AppStorage("settings.closedCaptions") private var closedCaptions = false

    private let pink = Color(hex: "E40063")

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            // LANGUAGE
            row(icon: "globe", title: "LANGUAGE") {
                LanguageToggle(selection: $language)
                    // TODO: drive real localization off this value.
            }

            // SFX
            row(icon: "speaker.wave.2.fill", title: "SFX") {
                SussSlider(value: $sfxVolume)
                    // TODO: route to the SFX audio channel.
            }

            // BGM
            row(icon: "speaker.wave.2.fill", title: "BGM") {
                SussSlider(value: $bgmVolume)
                    // TODO: route to the BGM audio channel.
            }

            // CLOSE CAPTIONS
            HStack {
                labelRow(icon: "captions.bubble.fill", title: "CLOSE\nCAPTIONS")
                Spacer()
                Toggle("", isOn: $closedCaptions)
                    .labelsHidden()
                    .tint(pink)
                    // TODO(pafras): show/hide the live captions when this is on.
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Full-height drawer with the same pink-bg + rounded-top styling as the
        // other drawers (SussConfirmDrawer / enter-code).
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(40)
        .presentationBackground {
            Color(hex: "F27CD8")
                .overlay(alignment: .top) {
                    Image("pink-bg").resizable().scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()
        }
    }

    // MARK: header (title + close X action button)

    private var header: some View {
        HStack {
            SussText(text: "SETTINGS", style: .largeTitle,
                     fill: Color(hex: "2A1AE8"), stroke: Color(hex: "8FE0FF"))
            Spacer()
            Button(action: onClose) {
                StrokedIcon(systemName: "xmark", assetName: "icon-close",
                            size: 16, fill: pink, stroke: .white)
                    .frame(width: 44, height: 44)
            }
            .glassButton()
        }
        .padding(.top, 20)
    }

    // MARK: reusable row (icon + pink stroked title, then a control below)

    private func row<Control: View>(icon: String, title: String,
                                    @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labelRow(icon: icon, title: title)
            control()
        }
    }

    private func labelRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            StrokedIcon(systemName: icon, size: 18, fill: pink, stroke: .white, strokeWidth: 3)
            SussText(text: title, style: .title3, fill: pink, stroke: .white)
        }
    }
}

// MARK: - EN / ID segmented toggle

private struct LanguageToggle: View {
    @Binding var selection: String
    private let options = ["EN", "ID"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                let on = selection == opt
                Text(opt)
                    .sussFont(.body1Bold)
                    .foregroundStyle(Color(hex: "E40063"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.7))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(.white, lineWidth: 2))
                                .padding(4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = opt
                        }
                    }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "E40063").opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 2))
        }
    }
}

// MARK: - Pink slider

private struct SussSlider: View {
    @Binding var value: Double

    var body: some View {
        Slider(value: $value)
            .tint(Color(hex: "E40063"))
    }
}

#Preview {
    Color(hex: "1A1A1A").ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SettingsView(onClose: {})
        }
}
#endif
