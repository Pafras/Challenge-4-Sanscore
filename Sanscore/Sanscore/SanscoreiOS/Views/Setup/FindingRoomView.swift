// JoinRoomView.swift
// Screen 2 — Join Room searching. Shows "FINDING ROOOOM" with animated bars
// while scanning for nearby hosts via MultipeerConnectivity. When a room is
// found, auto-navigates to JoinRoomView2 (room list).
//
// OWNER: Agung. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)
import MultipeerConnectivity

struct FindingRoomView: View {
    let vm: GameViewModel
    let dismissAll: () -> Void

    // The search never fails on its own: MultipeerConnectivity just keeps
    // looking. Without this the player stares at spinning bars forever whether
    // the host is on another Wi-Fi, in another room, or simply has not created
    // one yet — and identically if they denied the Local Network prompt, which
    // iOS gives us no way to query. So after a while, say what to check.
    @State private var showHint = false
    private let hintDelay: Duration = .seconds(8)

    var body: some View {
        ZStack {
            Image("pink-bg")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("finding-room-2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320)

                LoadingBarsView()
                    .padding(.top, 16)

                if showHint {
                    VStack(spacing: 14) {
                        Text("No rooms yet. Make sure you're in the same room, Wi-Fi and Bluetooth are on, and Sanscore is allowed to find devices on your local network in Settings.")
                            .font(.system(size: 15, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 36)

                        Button("Search again") {
                            showHint = false
                            vm.startBrowsing()
                        }
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .glassButton()
                    }
                    .padding(.top, 28)
                    .transition(.opacity)
                }

                Spacer()
            }
        }
        .animation(.easeInOut, value: showHint)
        // Restarts with the view, and again on every "Search again".
        .task(id: showHint) {
            guard !showHint else { return }
            try? await Task.sleep(for: hintDelay)
            showHint = true
        }
        .navigationBarBackButtonHidden(true)
        // Back button — design-system action button, identical to JoinRoomView's.
        .overlay(alignment: .topLeading) {
            Button {
                vm.room.stopBrowsing()
                dismissAll()
            } label: {
                StrokedIcon(systemName: "chevron.left", assetName: "icon-back",
                            size: 18, fill: Color(hex: "E40063"), stroke: .white)
                    .frame(width: 44, height: 44)
            }
            .glassButton()
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .navigationDestination(isPresented: .constant(!vm.room.foundRooms.isEmpty)) {
            JoinRoomView(vm: vm, dismissAll: dismissAll)
        }
    }
}

private struct LoadingBarsView: View {
    @State private var animate = false
    private let barCount = 5
    private let barWidth: CGFloat = 4
    private let maxHeight: CGFloat = 28
    private let minHeight: CGFloat = 8

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: barWidth, height: animate ? maxHeight : minHeight)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    NavigationStack {
        FindingRoomView(vm: GameViewModel(), dismissAll: {})
    }
}
#endif
