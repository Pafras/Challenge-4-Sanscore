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
            // Room alert (you left / host closed) as the design-system toast,
            // pinned to the top — not floating mid-screen under the logo.
            .overlay(alignment: .top) {
                if let alert = vm.roomAlert {
                    SusToastView(toast: Toast(message: alert, style: .neutral)) {
                        vm.dismissRoomAlert()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.default, value: vm.roomAlert)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showBrowser) {
                NavigationStack {
                    // FindingRoomView = the room-list browser (was JoinRoomView before
                    // Agung's rename). It navigates on to JoinRoomView (the numpad).
                    FindingRoomView(vm: vm, dismissAll: { showBrowser = false })
                }
            }
        }
    }
}

#Preview {
    RoomSetupView(vm: GameViewModel())
}
