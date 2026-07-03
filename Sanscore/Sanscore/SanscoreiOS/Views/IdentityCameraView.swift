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
    @State private var thumbBounce = false

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
            // Background crossfade (gradients now; swap for images later).
            IdentityGradient.bright.opacity(isTake ? 1 : 0).ignoresSafeArea()
            IdentityGradient.dark.opacity(isTake ? 0 : 1).ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 40) {
                    IdentityTitle(text: isTake ? "MAKE YOUR\nIDENTITY" : "YOU'RE\nALL SET!!")

                    // Camera row: circle fixed in the middle; templates peek in
                    // TAKE state only.
                    ZStack {
                        // Colour carousel (TAKE only) — circles slide with the
                        // drag, Instagram-filter style; the centered one is the
                        // background colour. They pass behind the camera circle.
                        // Window of circles around the center. Each is keyed by
                        // its ABSOLUTE index v so it keeps identity and slides
                        // (no snap-to-middle); new v's recycle in at the edges,
                        // colours wrap → infinite loop, both sides always full.
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

                    if isTake {
                        Text("Take a photo as your\ndisplay picture for identity")
                            .font(.system(size: 17, weight: .semibold))   // SF Pro
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .transition(.opacity)
                    } else {
                        swipeDownHint.transition(.opacity)
                    }
                }

                Spacer()

                if isTake {
                    // Shutter — Liquid Glass, 104×104.
                    Button(action: capture) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 104, height: 104)
                    }
                    .glassEffect(.regular.interactive(), in: Circle())
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 56)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .task {
            bgIndex = min(max(0, initialIndex), palette.count - 1)
            camera.setBackground(UIColor(palette[bgIndex]))
            await camera.start()
        }
        .onAppear { thumbBounce = true }
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
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private var swipeDownHint: some View {
        VStack(spacing: 6) {
            Text("Swipe Down")
                .font(.system(size: 15, weight: .semibold))   // SF Pro
                .foregroundStyle(.white)
            // TODO(satria): replace with the real hand line-art (Component 1).
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(y: thumbBounce ? 8 : -2)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                           value: thumbBounce)
        }
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
        withAnimation(.easeInOut(duration: 0.35)) { captured = shot }   // morph in place
    }

    private func placeholderImage() -> UIImage {
        let size = CGSize(width: 240, height: 240)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(liveColor).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func retake() {
        withAnimation(.easeInOut(duration: 0.3)) { captured = nil; dragY = 0 }
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

#Preview {
    IdentityCameraView(onCapture: { _ in })
}
#endif
