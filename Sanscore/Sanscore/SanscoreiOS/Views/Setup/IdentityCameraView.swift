// IdentityCameraView.swift
// The whole identity flow as ONE morphing screen (Figma: "Take a picture" →
// "Slide to enter"). No page transition — the same view swaps its content:
//
//   TAKE state  (captured == nil):
//     • title "MAKE YOUR IDENTITY"
//     • LIVE camera (background removed) in the middle circle
//     • colour templates peek left/right; swipe to change background colour
//     • big Liquid-Glass camera button = shutter
//
//   ALL-SET state (captured != nil):  ← shutter morphs here IN PLACE
//     • templates gone, background image crossfades, big button gone
//     • title "YOU'RE ALL SET!!"
//     • small retake camera badge on the photo
//     • JOIN button → onEnter (tap to enter the room)
//
// OWNER: Marleen. Self-contained UI + capture logic — does NOT edit
// GameViewModel / GameState. Hands the photo back via onCapture; the "enter the
// room" hookup is onEnter (Pafras wires it into the flow later).
// See HANDOFF-UI.md.
//
// TODO(satria): drop the real hand line-art ("Component 1") in for the thumb;
// for now it's an animated chevron. Background images can replace the gradients
// (image-to-image crossfade) — the crossfade hook is already here.

import SwiftUI
#if os(iOS)
import AVFoundation
import Vision
import CoreImage.CIFilterBuiltins

struct IdentityCameraView: View {
    var initialIndex: Int = 0
    /// Player's name, shown in the ALL-SET title ("AGUNG READY!!"). Empty = generic.
    var name: String = ""
    /// Finished, background-replaced photo + the chosen palette colour index.
    /// Caller passes both to vm.setMyAvatar (the colour drives the name badge).
    var onCapture: (UIImage, Int) -> Void
    /// Swipe-down "enter" action. Pafras wires this to the room; default = nothing.
    var onEnter: () -> Void = {}
    var onClose: () -> Void = {}

    @State private var camera = IdentityCamera()
    @State private var bgIndex = 0                   // TAKE: centered colour slot (unbounded)
    @State private var dragX: CGFloat = 0            // TAKE: live horizontal drag
    @State private var captured: UIImage? = nil      // nil = TAKE, set = ALL-SET

    // Pass previewCaptured (a photo) to open straight in the ALL-SET / Slide-to-
    // enter state — used by #Preview so you don't have to tap the shutter first.
    init(initialIndex: Int = 0,
         name: String = "",
         previewCaptured: UIImage? = nil,
         onCapture: @escaping (UIImage, Int) -> Void,
         onEnter: @escaping () -> Void = {},
         onClose: @escaping () -> Void = {}) {
        self.initialIndex = initialIndex
        self.name = name
        self.onCapture = onCapture
        self.onEnter = onEnter
        self.onClose = onClose
        _captured = State(initialValue: previewCaptured)
    }

    private let palette = IdentityPalette.colors
    private let cameraSize: CGFloat = 275
    private let optionSize: CGFloat = 167
    private let gap: CGFloat = 32

    private var isTake: Bool { captured == nil }
    // Center-to-center spacing so a side option sits `gap` from the camera edge.
    private var step: CGFloat { cameraSize / 2 + gap + optionSize / 2 }

    // Nearest colour slot for a given drag, clamped to the palette (finite).
    private func targetIndex(_ tx: CGFloat) -> Int {
        min(max(0, bgIndex - Int((tx / step).rounded())), palette.count - 1)
    }
    private var liveColor: Color { palette[targetIndex(dragX)] }

    var body: some View {
        ZStack {
            if !isTake {   // glow only on profile-confirm, not Take-a-picture
                GeometryReader { geo in
                    Ellipse()
                        .fill(Color(hex: "01E0FF"))
                        .frame(width: 500, height: 350)
                        .blur(radius: 70)
                        .position(x: geo.size.width / 2, y: geo.size.height * 1.09)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            VStack(spacing: 24) {
                // TOP half — title hugs the bottom, so it sits a gap ABOVE the
                // circle. Equal flexible height with the bottom half keeps the
                // circle pinned to screen center in BOTH states.
                VStack {
                    Spacer()
                    IdentityTitle(text: isTake ? String(localized: "TAKE YOUR\nPICTURE")
                                        : (name.isEmpty ? String(localized: "YOU'RE\nALL SET!!") : "\(name.uppercased())\nREADY!!"),
                                  tilt: isTake ? 3 : -3)
                }
                .frame(maxHeight: .infinity)

                // Camera circle = the fixed pivot (never moves between states).
                ZStack {
                    if isTake {
                        ForEach(palette.indices, id: \.self) { i in
                            optionCircle(palette[i])
                                .offset(x: CGFloat(i - bgIndex) * step + dragX)
                        }
                    }
                    circle
                        .overlay(alignment: .bottomTrailing) {
                            if !isTake { retakeBadge.offset(x: 6, y: 6) }
                        }
                }
                .contentShape(Rectangle())
                .gesture(rowGesture)

                // BOTTOM half — content changes per state; circle stays centered.
                // TAKE: caption hugs the top (just below circle).
                // ALL-SET: swipe hint drops to the bottom (near the thumb).
                VStack {
                    if isTake {
                        Text("Take a photo as your\ndisplay picture for identity")
                            .font(.system(size: 17, weight: .semibold))   // SF Pro
                            .fontWidth(.expanded)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .transition(.opacity)
                        Spacer()
                    } else {
                        Spacer()
                            .frame(height: 64)
                        // Profile confirm CTA: JOIN → enter the lobby.
                        Button(action: onEnter) {
                            IdentityTitle(text: String(localized: "JOIN"), size: 26, strokeWidth: 4, tilt: 0)
                        }
                        .buttonStyle(.sussGlisten)
                        .padding(.bottom, 56)
                        .transition(.opacity)
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
            }

            // Shutter on its OWN bottom-pinned layer (TAKE only) so the content
            // above stays vertically centered, independent of the button.
            if isTake {
                VStack {
                    Spacer()
                    Button(action: capture) {
                        CameraGlyph(size: 40)
                            .frame(width: 104, height: 104)
                    }
                    .glassButton()
                }
                .transition(.opacity)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill screen (else shrinks to content)
        // Background bleeds edge-to-edge; foreground keeps its safe area.
        // TAKE = bright "Default" bg, ALL-SET = dark "Set" bg.
        .background {
            ZStack {   // crossfade the two bgs instead of swapping instantly
                Image("Setup Profile-Default").resizable().scaledToFill()
                    .opacity(isTake ? 1 : 0)
                Image("Setup Profile-Set").resizable().scaledToFill()
                    .opacity(isTake ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            // BACK steps through the whole setup: confirm → retake photo →
            // (onClose) name entry. Pink chevron on light glass, per Figma.
            Button {
                if isTake { onClose() } else { retake() }
            } label: {
                StrokedIcon(systemName: "chevron.left", assetName: "icon-back",
                            size: 18, fill: Color(hex: "E40063"), stroke: .white)
                    .frame(width: 44, height: 44)
            }
            .glassButton()
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .task {
            bgIndex = min(max(0, initialIndex), palette.count - 1)
            camera.setBackground(UIColor(palette[bgIndex]))
            await camera.start()
        }
        .onDisappear { camera.stop() }
    }

    // MARK: - Pieces

    // The middle circle: live camera (TAKE) or frozen photo (ALL-SET).
    private var circle: some View {
        Group {
            if let captured {
                Image(uiImage: captured).resizable().scaledToFill()
            } else if let frame = camera.previewImage {
                Image(uiImage: frame).resizable().scaledToFill()
            } else {
                ZStack { liveColor; ProgressView().tint(.white) }   // Simulator / warming up
            }
        }
        .frame(width: cameraSize, height: cameraSize)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 8))
    }

    private func optionCircle(_ c: Color) -> some View {
        Circle()
            .fill(c)
            .frame(width: optionSize, height: optionSize)
            .opacity(0.95)
            .overlay(Circle().strokeBorder(.white, lineWidth: 5))
    }

    // Retake badge — glass circle, PINK camera icon (Figma reference).
    private var retakeBadge: some View {
        Button(action: retake) {
            CameraGlyph(size: 24)
                .frame(width: 72, height: 72)          // Figma: 72×72 action button
        }
        .glassButton()
    }

    // MARK: - Gestures / actions

}

/// Camera icon. Uses the REAL Figma icon if the asset "icon-camera" exists in
/// Assets.xcassets (export it from Figma as PDF/SVG, tick "Preserve Vector
/// Data"); until then, falls back to a clean pink SF Symbol.
/// TODO(marleen): export the Figma camera icon → drop into Assets as
/// "icon-camera" — it will appear here automatically, no code change.
struct CameraGlyph: View {
    var size: CGFloat = 24

    var body: some View {
        if UIImage(named: "icon-camera") != nil {
            Image("icon-camera")
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.3, height: size * 1.3)
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color(hex: "E40063"))
        }
    }
}

extension IdentityCameraView {

    // TAKE only: horizontal drag cycles the background colour. (ALL-SET has no
    // gesture — the JOIN button enters the room; swipe-to-enter was removed.)
    private var rowGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { v in
                guard isTake else { return }
                dragX = v.translation.width                          // circles follow finger
                camera.setBackground(UIColor(palette[targetIndex(dragX)]))  // bg live
            }
            .onEnded { v in
                guard isTake else { return }
                let target = targetIndex(v.translation.width)       // snap to nearest
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    bgIndex = target
                    dragX = 0
                }
                camera.setBackground(UIColor(palette[target]))
            }
    }

    private func capture() {
        AudioManager.shared.playSFX(.camera)
        // Fall back to a solid-colour photo when there's no camera frame yet
        // (Simulator / #Preview / warming up) so the flow is always testable.
        let shot = camera.latestFrame ?? placeholderImage()
        let colorIndex = min(max(0, bgIndex), palette.count - 1)   // chosen bg colour
        onCapture(shot, colorIndex)                       // save avatar + its colour
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.12)) { captured = shot }   // fast, little bounce
    }

    private func placeholderImage() -> UIImage {
        let size = CGSize(width: 240, height: 240)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(liveColor).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func retake() {
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.12)) { captured = nil }
    }
}

// MARK: - Capture + segmentation engine (self-contained, no vm)

@Observable
final class IdentityCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Latest background-replaced frame, updated on the main thread for SwiftUI.
    var previewImage: UIImage?
    /// Non-published copy the shutter reads (same value, avoids a race).
    var latestFrame: UIImage?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "sanscore.identity.camera")
    private let ciContext = CIContext()
    private let request: VNGeneratePersonSegmentationRequest = {
        let r = VNGeneratePersonSegmentationRequest()
        r.qualityLevel = .balanced          // real-time friendly
        r.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return r
    }()

    private let lock = NSLock()
    private var bgColor = CIColor(red: 1.0, green: 0.42, blue: 0.42)

    func setBackground(_ color: UIColor) {
        let ci = CIColor(color: color)
        lock.lock(); bgColor = ci; lock.unlock()
    }

    func start() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { return }
        queue.async { [self] in
            if session.inputs.isEmpty { configure() }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                    kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        // Orientation is fixed in captureOutput (rotate the CIImage), not on the
        // connection — that's reliable across devices/OS versions.
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let camera = CIImage(cvPixelBuffer: pixelBuffer)

        // Composite person over the chosen colour. If segmentation fails for a
        // frame, fall back to the raw camera image so the preview never freezes.
        var final = camera
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        if (try? handler.perform([request])) != nil,
           let maskBuffer = request.results?.first?.pixelBuffer {
            var mask = CIImage(cvPixelBuffer: maskBuffer)
            let sx = camera.extent.width / mask.extent.width
            let sy = camera.extent.height / mask.extent.height
            mask = mask.transformed(by: .init(scaleX: sx, y: sy))

            lock.lock(); let color = bgColor; lock.unlock()
            let background = CIImage(color: color).cropped(to: camera.extent)

            let blend = CIFilter.blendWithMask()
            blend.inputImage = camera
            blend.backgroundImage = background
            blend.maskImage = mask
            if let out = blend.outputImage { final = out }
        }

        // Fisheye / bulge selfie look (matches the Figma face). Positive scale
        // bulges the center outward. Tune: scale 0 = off, higher = more bulge;
        // smaller radius = tighter bulge.
        let bump = CIFilter.bumpDistortion()
        bump.inputImage = final
        bump.center = CGPoint(x: camera.extent.midX, y: camera.extent.midY)
        bump.radius = Float(min(camera.extent.width, camera.extent.height) * 0.75)
        bump.scale = 0.5
        if let bulged = bump.outputImage?.cropped(to: camera.extent) { final = bulged }

        // Sensor delivers landscape. Rotate to an upright, mirrored selfie.
        // If it comes out sideways/flipped on YOUR device, swap .leftMirrored
        // for one of: .rightMirrored, .right, .up (front-camera orientation
        // varies by hardware).
        let portrait = final.oriented(.leftMirrored)
        guard let cg = ciContext.createCGImage(portrait, from: portrait.extent) else { return }
        let image = UIImage(cgImage: cg)
        DispatchQueue.main.async { [weak self] in
            self?.previewImage = image
            self?.latestFrame = image
        }
    }
}

#Preview("Take a picture") {
    IdentityCameraView(onCapture: { _, _ in })
}

#Preview("Slide to enter") {
    // Seed a photo so it opens straight in the ALL-SET state (JOIN button).
    let photo = UIGraphicsImageRenderer(size: .init(width: 220, height: 220)).image { ctx in
        UIColor(red: 1, green: 0.42, blue: 0.42, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 220, height: 220))
    }
    return IdentityCameraView(previewCaptured: photo, onCapture: { _, _ in })
}
#endif
