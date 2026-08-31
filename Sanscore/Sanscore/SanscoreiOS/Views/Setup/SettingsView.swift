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

    // Sliders write UserDefaults; poke the live players so it applies instantly.

    private let pink = Color(hex: "E40063")

    // Apple Intelligence powers the verdict line only — never the score.
    private var llmNote: String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return nil }
        switch StructureAnalyzer.status {
        case .offInSettings:
            return String(localized: "Turn on Apple Intelligence in Settings for sharper, funnier verdicts. Scores are unaffected.")
        case .stillDownloading:
            return String(localized: "Apple Intelligence is still downloading — verdicts get funnier once it finishes.")
        case .available, .unsupported:
            return nil
        }
        #else
        return nil
        #endif
    }

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

            // CLOSE CAPTIONS — custom pink toggle (Figma). Same key
            // ClosedCaptionView reads, so flipping it shows/hides captions live.
            HStack {
                labelRow(icon: "captions.bubble.fill", title: "CLOSE\nCAPTIONS")
                Spacer()
                SussToggle(isOn: $closedCaptions)
            }

            // Only shown when the player can actually DO something about it: a
            // supported iPhone with Apple Intelligence switched off, or one still
            // downloading the model. An unsupported iPhone is told nothing — the
            // game scores identically either way, and the LLM only writes the
            // funny line, so there is nothing to apologise for.
            if let note = llmNote {
                Text(note)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .onChange(of: sfxVolume) { _, _ in AudioManager.shared.refreshVolumes() }
        .onChange(of: bgmVolume) { _, _ in AudioManager.shared.refreshVolumes() }
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
            SussText(text: title, style: .title3, fill: pink, stroke: .white,
                     textAlignment: .left)   // 2-line titles (CLOSE\nCAPTIONS) align left
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
                // Stroked like the row titles (pink fill, white outline).
                SussText(text: opt, style: .title3,
                         fill: Color(hex: "E40063"), stroke: .white)
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

// MARK: - Pink slider (custom, Figma look — stock Slider can't be restyled)

private struct SussSlider: View {
    @Binding var value: Double   // 0...1
    private let trackH: CGFloat = 14
    private let knob: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = CGFloat(value) * (w - knob) + knob / 2   // knob center

            ZStack(alignment: .leading) {
                // Base track: light pink, white border.
                Capsule()
                    .fill(.white.opacity(0.45))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                    .frame(height: trackH)
                // Filled part: pink gradient up to the knob, white stroke like
                // the base track.
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "FF7BC8"), Color(hex: "E40063")],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                    .frame(width: max(trackH, x), height: trackH)
                // Knob: pink ball, white ring.
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "FF5AA9"), Color(hex: "E40063")],
                                         center: .center, startRadius: 0, endRadius: knob / 2))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                    .position(x: x, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        value = min(max(0, Double((g.location.x - knob / 2) / (w - knob))), 1)
                    }
            )
        }
        .frame(height: 34)
    }
}

// MARK: - Pink toggle (custom, Figma look)

private struct SussToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            AudioManager.shared.playSFX(.click)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn
                      ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FF7BC8"), Color(hex: "E40063")],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.white.opacity(0.35)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                .frame(width: 76, height: 42)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color(hex: "FFE3F2"))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .frame(width: 34, height: 34)
                        .padding(4)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Color(hex: "1A1A1A").ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SettingsView(onClose: {})
        }
}
#endif
