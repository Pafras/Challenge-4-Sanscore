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

                Spacer()
            }
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
