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
//     • "Swipe Down" indicator + thumb animation; drag down → onEnter
//
// OWNER: Marleen. Self-contained UI + capture logic — does NOT edit
// GameViewModel / GameState. Hands the photo back via onCapture; the swipe-down
// "enter the room" hookup is onEnter (Pafras wires it into the flow later).
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
    /// Finished, background-replaced photo. Caller passes to vm.setMyAvatar.
    var onCapture: (UIImage) -> Void
    /// Swipe-down "enter" action. Pafras wires this to the room; default = nothing.
    var onEnter: () -> Void = {}
    var onClose: () -> Void = {}

    @State private var camera = IdentityCamera()
    @State private var bgIndex = 0                   // TAKE: centered colour slot (unbounded)
    @State private var dragX: CGFloat = 0            // TAKE: live horizontal drag
    @State private var captured: UIImage? = nil      // nil = TAKE, set = ALL-SET
    @State private var dragY: CGFloat = 0            // ALL-SET: drag photo out

    // Pass previewCaptured (a photo) to open straight in the ALL-SET / Slide-to-
    // enter state — used by #Preview so you don't have to tap the shutter first.
    init(initialIndex: Int = 0,
         previewCaptured: UIImage? = nil,
         onCapture: @escaping (UIImage) -> Void,
         onEnter: @escaping () -> Void = {},
         onClose: @escaping () -> Void = {}) {
        self.initialIndex = initialIndex
        self.onCapture = onCapture
        self.onEnter = onEnter
        self.onClose = onClose
        _captured = State(initialValue: previewCaptured)
    }

    private let palette = IdentityPalette.colors
    private let cameraSize: CGFloat = 275
    private let optionSize: CGFloat = 167
    private let gap: CGFloat = 32
    private let swipeThreshold: CGFloat = 160

    private var isTake: Bool { captured == nil }
    // Center-to-center spacing so a side option sits `gap` from the camera edge.
    private var step: CGFloat { cameraSize / 2 + gap + optionSize / 2 }

    // Nearest colour slot for a given drag, clamped to the palette (finite).
    private func targetIndex(_ tx: CGFloat) -> Int {
        min(max(0, bgIndex - Int((tx / step).rounded())), palette.count - 1)
    }
    private var liveColor: Color { palette[targetIndex(dragX)] }

    // Drag-down shrink/fade (ALL-SET only).
    private var photoScale: CGFloat { isTake ? 1 : max(0.35, 1 - dragY / 700) }
    private var photoOpacity: Double { isTake ? 1 : max(0, 1 - dragY / 400) }

    var body: some View {
        ZStack {
            if !isTake {
                VStack {
                    Spacer()
                    ThumbSwipe()
                        .frame(width: 220, height: 200)
                        .offset(x: 24)          // nudge right
                }
                .allowsHitTesting(false)
                .transition(.opacity)          // fade in/out, don't pop
            }

            if !isTake {   // glow only on Slide-to-enter, not Take-a-picture
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
                    IdentityTitle(text: isTake ? "TAKE YOUR\nPICTURE" : "YOU'RE\nALL SET!!", tilt: isTake ? 3:-3)
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
                        .scaleEffect(photoScale)
                        .offset(y: dragY)
                        .opacity(photoOpacity)
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
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .transition(.opacity)
                        Spacer()
                    } else {
                        Spacer()
                        swipeDownHint.transition(.opacity)
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
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 104, height: 104)
                    }
                    .glassButton()
                }
                .transition(.opacity)
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
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
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

    private var retakeBadge: some View {
        Button(action: retake) {
            Image(systemName: "camera.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
        }
        .glassButton()
    }

    private var swipeDownHint: some View {
        VStack(spacing: 8) {
            Text("Swipe Down")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Image(systemName: "chevron.down.2")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }.shadow(radius: 3)
        .opacity(photoOpacity)
    }

    // MARK: - Gestures / actions

    // One drag: horizontal cycles colour (TAKE); vertical drags the photo out (ALL-SET).
    private var rowGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { v in
                if isTake {
                    dragX = v.translation.width                          // circles follow finger
                    camera.setBackground(UIColor(palette[targetIndex(dragX)]))  // bg live
                } else {
                    dragY = max(0, v.translation.height)
                }
            }
            .onEnded { v in
                if isTake {
                    let target = targetIndex(v.translation.width)       // snap to nearest
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        bgIndex = target
                        dragX = 0
                    }
                    camera.setBackground(UIColor(palette[target]))
                } else if v.translation.height > swipeThreshold {
                    withAnimation(.easeIn(duration: 0.25)) { dragY = 900 }
                    onEnter()
                } else {
                    withAnimation(.spring) { dragY = 0 }
                }
            }
    }

    private func capture() {
        // Fall back to a solid-colour photo when there's no camera frame yet
        // (Simulator / #Preview / warming up) so the flow is always testable.
        let shot = camera.latestFrame ?? placeholderImage()
        onCapture(shot)                                   // save avatar
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
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.12)) { captured = nil; dragY = 0 }
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

// MARK: - Thumb swipe hint (Satria's Component 1, native — no Lottie)

/// The line-art thumb that morphs flat → flicked-up and back, forever.
/// Same shape data as the Lottie (`thumb-swipe-up.json`), drawn natively so the
/// app needs no external animation library.
struct ThumbSwipe: View {
    var body: some View {
        // progress 1 = pose up, 0 = pose down. Loop: hold up → swipe down →
        // hold down → back up. KeyframeAnimator repeats forever by default.
        KeyframeAnimator(initialValue: 1.0) { p in
            ThumbSwipeShape(progress: p)
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        } keyframes: { _ in
            // No static pauses — slow over-drifts instead (shape extrapolates
            // past the pose, so it keeps drifting gently, never looks frozen).
            CubicKeyframe(1.08,  duration: 0.9)    // drift a bit FURTHER up (slow, longest)
            CubicKeyframe(0.0,   duration: 0.45)   // swipe down
            CubicKeyframe(-0.08, duration: 0.5)    // drift a bit FURTHER down (slow)
            CubicKeyframe(1.0,   duration: 0.6)    // back to original (up), then loop
        }
    }
}

/// Morphs the finger + nail outlines between the two Figma poses. `progress`
/// 0→1 lerps every vertex/tangent (poses have matching point counts). Drawn in
/// the 138×152 Figma coordinate space, scaled to fit.
struct ThumbSwipeShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // Finger (open path, 8 pts) — pose 1 (flat) / pose 2 (up).
    private static let fV1: [CGPoint] = [.init(x:128.129,y:148.622),.init(x:89.6598,y:130.118),.init(x:29.5407,y:110.026),.init(x:4.0025,y:78.9607),.init(x:42.8777,y:69.4228),.init(x:69.3791,y:74.612),.init(x:112.08,y:85.3315),.init(x:130.834,y:83.7398)]
    private static let fO1: [CGPoint] = [.init(x:-7.063,y:-4.417),.init(x:-17.282,y:-5.252),.init(x:-18.433,y:-7.034),.init(x:6.087,y:-14.034),.init(x:17.319,y:2.703),.init(x:6.738,y:1.961),.init(x:14.275,y:0.207),.init(x:0,y:0)]
    private static let fI1: [CGPoint] = [.init(x:0,y:0),.init(x:13.825,y:4.202),.init(x:18.433,y:7.034),.init(x:-6.087,y:14.034),.init(x:-17.319,y:-2.703),.init(x:-6.738,y:-1.961),.init(x:-17.845,y:-0.259),.init(x:-0.303,y:0.617)]
    private static let fV2: [CGPoint] = [.init(x:94.9999,y:123.949),.init(x:76.4999,y:97.4494),.init(x:35.9999,y:54.9494),.init(x:28.5,y:2.94926),.init(x:59,y:21.4493),.init(x:84,y:42.4494),.init(x:117.5,y:68.4494),.init(x:135.5,y:78.4494)]
    private static let fO2: [CGPoint] = [.init(x:-5.5,y:-14.0),.init(x:-15.0,y:-20.5),.init(x:-11.858,y:-15.768),.init(x:12.625,y:-8.638),.init(x:12.395,y:12.395),.init(x:4.66,y:5.248),.init(x:11.974,y:7.776),.init(x:0,y:0)]
    private static let fI2: [CGPoint] = [.init(x:0,y:0),.init(x:8.533,y:11.662),.init(x:11.858,y:15.768),.init(x:-12.625,y:8.638),.init(x:-11.0,y:-11.0),.init(x:-4.66,y:-5.248),.init(x:-14.967,y:-9.72),.init(x:-0.585,y:0.361)]

    // Nail (closed path, 6 pts).
    private static let nV1: [CGPoint] = [.init(x:50.091,y:98.3995),.init(x:54.1105,y:85.4575),.init(x:41.0473,y:75.8708),.init(x:16.4281,y:72.9948),.init(x:8.3892,y:90.2508),.init(x:37.0278,y:108.945)]
    private static let nO1: [CGPoint] = [.init(x:3.2155,y:-6.1355),.init(x:-0.4938,y:-3.3553),.init(x:-8.0389,y:-2.3966),.init(x:-3.517,y:0.4794),.init(x:1.00486,y:9.1073),.init(x:11.0534,y:3.355)]
    private static let nI1: [CGPoint] = [.init(x:-4.0195,y:7.6695),.init(x:0.6699,y:1.2782),.init(x:8.0388,y:2.3967),.init(x:3.517,y:-0.4793),.init(x:-1.00486,y:-9.1073),.init(x:-11.0535,y:-3.356)]
    private static let nV2: [CGPoint] = [.init(x:55.5,y:38.9524),.init(x:63.5,y:31.9523),.init(x:58.4999,y:24.9523),.init(x:42.7632,y:6.9618),.init(x:31.5,y:6.96181),.init(x:39,y:31.9523)]
    private static let nO2: [CGPoint] = [.init(x:0,y:0),.init(x:1.3169,y:-1.9103),.init(x:-4.5003,y:-6.0),.init(x:-2.641,y:-2.34512),.init(x:-3.8036,y:4.94059),.init(x:5.9029,y:9.6164)]
    private static let nI2: [CGPoint] = [.init(x:0,y:0),.init(x:-1.3168,y:1.9104),.init(x:4.5002,y:6.0001),.init(x:2.6409,y:2.34512),.init(x:3.8036,y:-4.94058),.init(x:-5.903,y:-9.6163)]

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 138, rect.height / 152)
        let ox = (rect.width - 138 * s) / 2
        let oy = (rect.height - 152 * s) / 2
        func tf(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s + ox, y: p.y * s + oy) }

        var path = Path()
        addMorph(&path, Self.fV1, Self.fO1, Self.fI1, Self.fV2, Self.fO2, Self.fI2, closed: false, tf)
        addMorph(&path, Self.nV1, Self.nO1, Self.nI1, Self.nV2, Self.nO2, Self.nI2, closed: true, tf)
        return path
    }

    private func addMorph(_ path: inout Path,
                          _ v1: [CGPoint], _ o1: [CGPoint], _ i1: [CGPoint],
                          _ v2: [CGPoint], _ o2: [CGPoint], _ i2: [CGPoint],
                          closed: Bool, _ tf: (CGPoint) -> CGPoint) {
        let t = progress
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        let n = v1.count
        func v(_ k: Int) -> CGPoint { mix(v1[k], v2[k]) }
        func outCtrl(_ k: Int) -> CGPoint { let base = v(k); let r = mix(o1[k], o2[k]); return CGPoint(x: base.x + r.x, y: base.y + r.y) }
        func inCtrl(_ k: Int) -> CGPoint { let base = v(k); let r = mix(i1[k], i2[k]); return CGPoint(x: base.x + r.x, y: base.y + r.y) }

        path.move(to: tf(v(0)))
        for k in 0..<(n - 1) {
            path.addCurve(to: tf(v(k + 1)), control1: tf(outCtrl(k)), control2: tf(inCtrl(k + 1)))
        }
        if closed {
            path.addCurve(to: tf(v(0)), control1: tf(outCtrl(n - 1)), control2: tf(inCtrl(0)))
            path.closeSubpath()
        }
    }
}

#Preview("Take a picture") {
    IdentityCameraView(onCapture: { _ in })
}

#Preview("Slide to enter") {
    // Seed a photo so it opens straight in the ALL-SET state (thumb animates).
    let photo = UIGraphicsImageRenderer(size: .init(width: 220, height: 220)).image { ctx in
        UIColor(red: 1, green: 0.42, blue: 0.42, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 220, height: 220))
    }
    return IdentityCameraView(previewCaptured: photo, onCapture: { _ in })
}
#endif
