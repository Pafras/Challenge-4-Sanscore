// TakePictureView.swift
// Screen 3 — identity / take a photo (Figma: "Take a picture" / "MAKE YOUR
// IDENTITY"). Photo (take/retake) + swipeable background colour.
//
// OWNER: Marleen. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.
//
// NOTE: today this is shown as a sheet from Home/Lobby. Figma wants it as a
// full step BEFORE the room. Re-ordering the flow = new GameState + vm method =
// Pafras's job. (Struct name stays EditProfileView so the sheets keep working.)
//
// FLAG(pafras): the old inline name field ("iPhone 17 Pro" prefilled from the
// device name) is REMOVED — it's not in Figma and read like a badge. This was
// also the lobby rename entry point, so rename now needs a home elsewhere
// (e.g. a small edit affordance in GameRoomView). Nothing here calls
// setDisplayName anymore.
//
// TODO(marleen): Figma wants a LIVE camera in the middle circle. That's the
// separate IdentityCameraView (AVFoundation + Vision background removal), opened
// by the shutter. This screen shows the captured photo (or a placeholder) and
// the swipeable colour templates.

import SwiftUI
#if os(iOS)

// The whole identity screen (Take a picture → You're all set) is now the ONE
// morphing IdentityCameraView. EditProfileView is a thin wrapper so the existing
// sheet call sites (lobby "edit photo", Home) keep working with no double title.
struct EditProfileView: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        IdentityCameraView(
            onCapture: { image in vm.setMyAvatar(image) },
            // In the real pre-room flow, Pafras wires the swipe-down to enter the
            // room. From the lobby sheet, swipe-down / back just closes.
            onEnter: { dismiss() },
            onClose: { dismiss() }
        )
    }
}

// MARK: - Shared identity bits (used here + in the other identity screens)

/// The colour palette you can swipe through (coral is the Figma default; the
/// rest echo the game-room bubble colours). Marleen will swap these for real
/// background images later.
enum IdentityPalette {
    static let colors: [Color] = [
        Color(red: 1.0,  green: 0.42, blue: 0.42),  // coral / red (default)
        Color(red: 0.10, green: 0.45, blue: 0.95),  // blue
        Color(red: 0.30, green: 0.78, blue: 0.40),  // green
        Color(red: 0.98, green: 0.85, blue: 0.15),  // yellow
        Color(red: 0.93, green: 0.45, blue: 0.85),  // pink
        Color(red: 0.55, green: 0.35, blue: 0.95),  // purple
    ]
}

/// Circular avatar on a plain colour, thick white ring — the look from the
/// identity screens. Shows the photo, or a camera placeholder.
/// (No more spider-web; Marleen will drop a background image in later.)
struct IdentityAvatar: View {
    var image: UIImage?
    var color: Color = IdentityPalette.colors[0]
    var size: CGFloat = 275

    var body: some View {
        ZStack {
            Circle().fill(color)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: size * 0.22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // strokeBorder (not stroke) draws the ring INSIDE the frame, so the
        // frame edge == the visible edge and the 32pt gaps stay exact.
        .overlay(Circle().strokeBorder(.white, lineWidth: 8))
    }
}

/// Blue backgrounds behind the identity screens.
enum IdentityGradient {
    /// Bright cyan→blue (Take a picture).
    static let bright = LinearGradient(
        colors: [Color(red: 0.16, green: 0.78, blue: 0.94),
                 Color(red: 0.08, green: 0.38, blue: 0.91)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Dark navy→blue (Slide to enter).
    static let dark = LinearGradient(
        colors: [Color(red: 0.04, green: 0.11, blue: 0.24),
                 Color(red: 0.05, green: 0.36, blue: 0.82)],
        startPoint: .top, endPoint: .bottom)
}

/// The Figma title: SF Pro Expanded heavy, white fill with a white-20% stroke
/// outline. SwiftUI has no native text stroke, so we draw the text 8 times
/// offset behind the fill — the classic outline trick. No drop shadow.
struct IdentityTitle: View {
    let text: String
    var size: CGFloat = 40
    var strokeWidth: CGFloat = 2

    private static let offsets: [(CGFloat, CGFloat)] =
        [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]

    private var base: some View {
        Text(text)
            .font(.system(size: size, weight: .black))
            .fontWidth(.expanded)                 // SF Pro Expanded
            .multilineTextAlignment(.center)
    }

    var body: some View {
        ZStack {
            ForEach(Array(Self.offsets.enumerated()), id: \.offset) { _, o in
                base.foregroundStyle(.white.opacity(0.2))    // stroke, white 20%
                    .offset(x: o.0 * strokeWidth, y: o.1 * strokeWidth)
            }
            base.foregroundStyle(.white)                       // fill
        }
    }
}

#Preview {
    EditProfileView(vm: GameViewModel())
}
#endif
