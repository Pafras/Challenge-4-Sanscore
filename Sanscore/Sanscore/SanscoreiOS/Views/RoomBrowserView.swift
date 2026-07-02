// RoomBrowserView.swift
// "Join room" screen — Apple's ready-made nearby-rooms list. Wraps
// MCBrowserViewController so SwiftUI can present it. Shows nearby hosts, tap to
// join. Zero custom discovery UI.
//
// Use: .sheet(isPresented:) { RoomBrowserView(room: room) }
//
// OWNER: Pafras (iOS).

#if os(iOS)
import SwiftUI
import MultipeerConnectivity

struct RoomBrowserView: UIViewControllerRepresentable {
    let room: RoomService
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MCBrowserViewController {
        let vc = MCBrowserViewController(serviceType: RoomService.serviceType, session: room.session)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MCBrowserViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, MCBrowserViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func browserViewControllerDidFinish(_ b: MCBrowserViewController) { dismiss() }
        func browserViewControllerWasCancelled(_ b: MCBrowserViewController) { dismiss() }
    }
}
#endif
