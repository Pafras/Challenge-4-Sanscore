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
import UIKit
import CoreText

// The whole identity screen (Take a picture → You're all set) is now the ONE
// morphing IdentityCameraView. EditProfileView is a thin wrapper so the existing
// sheet call sites (lobby "edit photo", Home) keep working with no double title.
struct EditProfileView: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        IdentityCameraView(
            onCapture: { image, colorIndex in vm.setMyAvatar(image, colorIndex: colorIndex) },
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
extension View {
    /// Circle ACTION button (X / back / camera badge) — Figma action button:
    /// light glass (white 50%), white 50% inside stroke 4, soft shadow.
    /// `dark: true` = game-room variant: 50% radial gradient 3F3F3F -> 000000,
    /// white 60% stroke (same system as `.sussDark`).
    /// Icon colour comes from the label (pink for chevrons/camera).
    @ViewBuilder
    func glassButton(dark: Bool = false) -> some View {
        if dark {
            background {
                Circle().fill(EllipticalGradient(
                    colors: [Color(hex: "3F3F3F"), Color(hex: "000000")],
                    center: .center))
                .opacity(0.5)
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 4))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        } else {
            glassEffect(.regular.tint(.white.opacity(0.5)).interactive(), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 4))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
    }
}

/// The design-system capsule button (Figma "BUTTON" component):
/// white 50% fill ENABLED → 80% PRESSED, white 50% inside stroke 4pt,
/// glass + SOFT drop shadow. Label supplies its own styling (pink stroked
/// title). `glisten: true` adds the sweeping light beam (Figma note on JOIN).
struct SussButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 40
    var glisten = false
    var dark = false          // dark-screen variant (game room): black glass
    var tint: Color = .white  // light-variant glass tint
    /// 50% radial-gradient fill instead of glass (drawer EXIT: FFC1EB -> EB0067).
    var gradientColors: [Color]? = nil

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        // Figma buttons: 50% radial gradient, centre -> edge
        // (elliptical = radial stretched to the button bounds, like Figma).
        let fill: [Color]? = dark
            ? [Color(hex: "3F3F3F"), Color(hex: "000000")]
            : gradientColors
        let padded = configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 16)

        return Group {
            if let fill {
                padded.background {
                    shape.fill(EllipticalGradient(colors: fill, center: .center))
                        .opacity(configuration.isPressed ? 0.8 : 0.5)
                }
            } else {
                padded.glassEffect(
                    .regular.tint(tint.opacity(configuration.isPressed ? 0.8 : 0.5)),
                    in: shape)
            }
        }
        .overlay { if glisten { GlistenBeam().clipShape(shape) } }
        // Inside stroke: dark variant = white 60%, light = white 50%.
        .overlay(shape.strokeBorder(.white.opacity(dark ? 0.6 : 0.5), lineWidth: 4))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        // Click SFX for every design-system button, fired on press-down.
        .onChange(of: configuration.isPressed) { _, pressed in
            if pressed { AudioManager.shared.playSFX(.click) }
        }
    }
}

extension ButtonStyle where Self == SussButtonStyle {
    static var suss: SussButtonStyle { SussButtonStyle() }
    /// JOIN-style: same button + sweeping glisten beam ("it's time to join").
    static var sussGlisten: SussButtonStyle { SussButtonStyle(glisten: true) }
    /// Dark-screen variant (game room START): black glass, same stroke.
    static var sussDark: SussButtonStyle { SussButtonStyle(dark: true) }
}

/// A soft diagonal light band sweeping across the button, looping with a pause.
private struct GlistenBeam: View {
    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.75), .clear],
                           startPoint: .leading, endPoint: .trailing)
                // Taller than the button so the 18°-tilted band still covers the
                // full height (same height = corners crop -> beam looks short).
                .frame(width: geo.size.width * 0.45, height: geo.size.height * 2.4)
                .rotationEffect(.degrees(18))
                .position(x: 0, y: geo.size.height / 2)
                .offset(x: sweep ? geo.size.width * 1.5 : -geo.size.width * 0.5)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1)
                        .delay(0.9)                       // pause between sweeps
                        .repeatForever(autoreverses: false)) { sweep = true }
                }
        }
        .allowsHitTesting(false)
    }
}

/// Small icon with a thick rounded outline (Figma style): SF Symbol fill +
/// stroke via offset copies. If an asset named `assetName` exists it is used
/// instead (export from Figma → Assets, like "icon-camera").
struct StrokedIcon: View {
    var systemName: String
    var assetName: String? = nil
    var size: CGFloat = 18
    var fill: Color = Color(hex: "E40063")
    var stroke: Color = .white
    var strokeWidth: CGFloat = 3

    private static let dirs: [CGPoint] = (0..<12).map { i in
        let a = Double(i) / 12 * 2 * .pi
        return CGPoint(x: cos(a), y: sin(a))
    }

    var body: some View {
        if let assetName, UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.4, height: size * 1.4)
        } else {
            ZStack {
                ForEach(Self.dirs.indices, id: \.self) { i in
                    Image(systemName: systemName)
                        .font(.system(size: size, weight: .heavy))
                        .foregroundStyle(stroke)
                        .offset(x: Self.dirs[i].x * strokeWidth,
                                y: Self.dirs[i].y * strokeWidth)
                }
                Image(systemName: systemName)
                    .font(.system(size: size, weight: .heavy))
                    .foregroundStyle(fill)
            }
        }
    }
}

extension Color {
    /// Make a Color from a hex string like "01E0FF" or "#01E0FF".
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        let v = UInt64(h, radix: 16) ?? 0
        self.init(red:   Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8)  & 0xFF) / 255,
                  blue:  Double( v        & 0xFF) / 255)
    }
}

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

/// The Figma title: SF Pro Expanded heavy, coloured fill with a REAL white
/// stroke around the letters (sharp miter corners, no ghost). Uses Core Text to
/// build the glyph path, then strokes + fills it in a UIView.
struct IdentityTitle: View {
    let text: String
    var size: CGFloat = 40
    var strokeWidth: CGFloat = 5                 // outline thickness (points OUTSIDE)
    var fill: Color = Color(hex: "FF2684")       // pink fill
    var stroke: Color = .white                   // outline colour (drawer title = light blue)
    var tilt: Double                     // degrees; negative = tilt up-right
    var lineHeightMultiple: CGFloat = 0.9        // <1 = tighter lines
    // Variable font axes (Figma: titles = Width 150 / Weight 1000 -> expanded
    // black; headline = Expanded Bold; body = Expanded Regular). Defaults keep
    // every existing call site the title look. See SussTypography.swift.
    var weight: UIFont.Weight = .black
    var width: UIFont.Width = .expanded

    var body: some View {
        StrokeTextLabel(text: text, fontSize: size, strokeWidth: strokeWidth,
                        fill: UIColor(fill), stroke: UIColor(stroke),
                        lineHeightMultiple: lineHeightMultiple,
                        weight: weight, width: width)
            .fixedSize()                          // size to the glyphs
            .rotationEffect(.degrees(tilt))
    }
}

/// SwiftUI bridge to the Core Text stroking view.
private struct StrokeTextLabel: UIViewRepresentable {
    var text: String
    var fontSize: CGFloat
    var strokeWidth: CGFloat
    var fill: UIColor
    var stroke: UIColor
    var lineHeightMultiple: CGFloat
    var weight: UIFont.Weight = .black
    var width: UIFont.Width = .expanded

    func makeUIView(context: Context) -> StrokeTextUIView { StrokeTextUIView() }
    func updateUIView(_ v: StrokeTextUIView, context: Context) {
        v.configure(text: text, fontSize: fontSize, strokeWidth: strokeWidth,
                    fill: fill, stroke: stroke, lineHeightMultiple: lineHeightMultiple,
                    weight: weight, width: width)
    }
}

/// Builds the multiline glyph outline (Core Text) and draws stroke-then-fill so
/// the outline sits OUTSIDE the letters with sharp miter joins.
final class StrokeTextUIView: UIView {
    private var glyphPath = CGMutablePath()
    private var fillColor: UIColor = .white
    private var strokeColor: UIColor = .white
    private var strokeW: CGFloat = 0
    private var contentSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { contentSize }

    func configure(text: String, fontSize: CGFloat, strokeWidth: CGFloat,
                   fill: UIColor, stroke: UIColor, lineHeightMultiple: CGFloat,
                   weight: UIFont.Weight = .black, width: UIFont.Width = .expanded) {
        fillColor = fill; strokeColor = stroke; strokeW = strokeWidth

        let font = UIFont.systemFont(ofSize: fontSize, weight: weight, width: width)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineHeightMultiple = lineHeightMultiple
        let attr = NSAttributedString(string: text,
                                      attributes: [.font: font, .paragraphStyle: para])

        let framesetter = CTFramesetterCreateWithAttributedString(attr)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil,
            CGSize(width: 2000, height: CGFloat.greatestFiniteMagnitude), nil)
        let bounds = CGRect(x: 0, y: 0, width: ceil(measured.width), height: ceil(measured.height))
        let ctFrame = CTFramesetterCreateFrame(
            framesetter, CFRange(location: 0, length: 0),
            CGPath(rect: bounds, transform: nil), nil)

        let lines = CTFrameGetLines(ctFrame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(ctFrame, CFRange(location: 0, length: 0), &origins)

        let path = CGMutablePath()
        for (i, line) in lines.enumerated() {
            let lineOrigin = origins[i]
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attrs = CTRunGetAttributes(run) as NSDictionary
                let runFont = attrs[kCTFontAttributeName as String] as! CTFont
                let count = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
                for j in 0..<count {
                    guard let gp = CTFontCreatePathForGlyph(runFont, glyphs[j], nil) else { continue }
                    let t = CGAffineTransform(translationX: lineOrigin.x + positions[j].x,
                                              y: lineOrigin.y + positions[j].y)
                    path.addPath(gp, transform: t)
                }
            }
        }
        // Core Text is y-up; flip into UIKit y-down space.
        var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
        glyphPath = CGMutablePath()
        if let flipped = path.copy(using: &flip) { glyphPath.addPath(flipped) }

        contentSize = CGSize(width: bounds.width + strokeWidth * 2,
                             height: bounds.height + strokeWidth * 2)
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), !glyphPath.isEmpty else { return }
        let b = glyphPath.boundingBoxOfPath
        ctx.saveGState()
        ctx.translateBy(x: (bounds.width - b.width) / 2 - b.minX,
                        y: (bounds.height - b.height) / 2 - b.minY)
        // Stroke first (2× width → half shows outside), fill on top.
        ctx.addPath(glyphPath)
        ctx.setLineWidth(strokeW * 2)
        ctx.setStrokeColor(strokeColor.cgColor)
        // Round join: miter spiked on sharp glyph corners (long pointy tips).
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.addPath(glyphPath)
        ctx.setFillColor(fillColor.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

#Preview {
    EditProfileView(vm: GameViewModel())
}
#endif
