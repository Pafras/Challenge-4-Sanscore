//
//  WarningView.swift
//  Sanscore
//
//  Created by Agung Ananda on 06/07/26.
//
//  Standalone "put your finger on the camera" warning. Shows while the app
//  needs a heart-rate reading but sees no finger covering the back camera.
//
//  LAYOUT (ZStack, bottom -> top):
//    1. LIVE back-camera feed (torch ON, so a finger on the lens glows red —
//       that's the same signal the PPG heart-rate reader uses).
//    2. pink-bg-camera   the pink art, used as a translucent TINT over the feed
//                        (it's an opaque image; at full opacity it hides the
//                        camera — that was the bug. We blend it now.)
//    3. warning-text     pulsing so it reads as urgent.
//
//  On Simulator / Xcode Preview there is no camera, so we just show the pink
//  art full-screen as a fallback (so the canvas isn't black).
//

import SwiftUI
#if os(iOS)
import AVFoundation
#endif

struct WarningView: View {

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    /// Width of the warning text art.
    private let textWidth: CGFloat = 350
    /// How much the text grows at the peak of each pulse (1.0 = no growth).
    private let pulseScale: CGFloat = 1.06
    /// Seconds for one pulse (grow + shrink).
    private let pulseSpeed: Double = 0.7
    /// How strong the pink tint sits over the live camera (0 = none, 1 = hides it).
    private let tintOpacity: Double = 0.65
    // ──────────────────────────────────────────────────────────────────────

    @State private var pulsing = false

    var body: some View {
        ZStack {
            // 1. + 2. Camera feed + pink tint (device), or pink fallback (Sim).
            #if os(iOS) && !targetEnvironment(simulator)
            BackCameraPreview()
                .ignoresSafeArea()

            // Pink art as a see-through tint. .multiply keeps the darks and
            // washes the feed pink. If it looks wrong, try .screen or just drop
            // .blendMode and rely on tintOpacity alone.
            Image("pink-bg-camera")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blendMode(.multiply)
                .opacity(tintOpacity)
            #else
            // Simulator / Preview: no camera — show the pink art solid.
            Image("pink-bg-camera")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            #endif

            // 3. Pulsing warning text.
            Image("warning-text")
                .resizable()
                .scaledToFit()
                .frame(width: textWidth)
                .scaleEffect(pulsing ? pulseScale : 1.0)
                .animation(
                    .easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true),
                    value: pulsing
                )
        }
        .onAppear { pulsing = true }
    }
}

// MARK: - Live back-camera preview (torch on)

#if os(iOS) && !targetEnvironment(simulator)
/// A bare AVCaptureVideoPreviewLayer showing the BACK camera with the torch on.
/// No frame processing — it's just a live viewfinder, so it's cheap.
final class TorchCameraUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "sanscore.warning.camera")
    private var device: AVCaptureDevice?

    func start() {
        Task {
            // Needs NSCameraUsageDescription in Info.plist (already set).
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { return }
            queue.async { [self] in
                if session.inputs.isEmpty { configure() }
                if !session.isRunning { session.startRunning() }
                setTorch(true)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            setTorch(false)
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        device = cam
        session.addInput(input)
        session.commitConfiguration()

        // Attach the running session to THIS view's preview layer on the main thread.
        DispatchQueue.main.async { [self] in
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }
    }

    /// Torch on = the finger over the lens lights up red (the PPG signal).
    private func setTorch(_ on: Bool) {
        guard let device, device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

/// SwiftUI wrapper. Starts the camera when it appears, stops it when it's gone.
struct BackCameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> TorchCameraUIView {
        let view = TorchCameraUIView()
        view.start()
        return view
    }
    func updateUIView(_ uiView: TorchCameraUIView, context: Context) {}
    static func dismantleUIView(_ uiView: TorchCameraUIView, coordinator: ()) {
        uiView.stop()
    }
}
#endif

#Preview {
    WarningView()
}
