// HomePageView.swift
// Screen 1 — the home/landing screen (Figma: "Homepage"). SUSS meter logo +
// JOIN + CREATE. Shown on GameState.idle.
//
// OWNER: Agung. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.
//
// (Struct name stays RoomSetupView so the root switch in GameFlowView keeps
// working; it's module-internal now, not `private`, so the switch can see it.)

import SwiftUI

struct RoomSetupView: View {
    @Bindable var vm: GameViewModel
    @State private var showBrowser = false

    var body: some View {   
        NavigationStack {
            ZStack {
                Image("pink-bg")
                    .resizable()
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    // Logo — centered in upper half
                    Image("sus-meter-2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)

                    // Alert (room closed, etc.)
                    if let alert = vm.roomAlert {
                        Label(alert, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.black.opacity(0.3), in: Capsule())
                    }

                    // JOIN button
                    Button {
                        vm.startBrowsing()
                        showBrowser = true
                    } label: {
                        Text("JOIN")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .tint(.pink)
                    .padding(.horizontal, 32)

                    // CREATE button
                    Button {
                        vm.createRoom()
                    } label: {
                        Text("CREATE")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .tint(.pink)
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showBrowser) {
                NavigationStack {
                    // FindingRoomView = the room-list browser (was JoinRoomView before
                    // Agung's rename). It navigates on to JoinRoomView (the numpad).
                    FindingRoomView(vm: vm, dismissAll: { showBrowser = false })
                }
            }
        }
        #if os(iOS)
        .task {
            _ = await RealSpeechCapture.requestPermission()
        }
        #endif
    }
}

#Preview {
    RoomSetupView(vm: GameViewModel())
}
