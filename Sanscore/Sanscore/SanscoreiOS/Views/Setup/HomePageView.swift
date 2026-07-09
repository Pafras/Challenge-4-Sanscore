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
    @State private var showSettings = false

    var body: some View {   
        NavigationStack {
            ZStack {
                Image("pink-bg")
                    .resizable()
                    .ignoresSafeArea()

                VStack(spacing: 5) {
                    Spacer()

                    // Logo — centered in upper half
                    Image("sus-meter-new")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)

                    // JOIN button (asset art — text is baked in)
                    Button {
                        vm.startBrowsing()
                        showBrowser = true
                    } label: {
                        Image("join-button-new")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    // CREATE button (asset art — text is baked in)
                    Button {
                        vm.createRoom()
                    } label: {
                        Image("create-button-new")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    Spacer()
                }

                // Settings gear — design-system action button, top-right.
                VStack {
                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            StrokedIcon(systemName: "gearshape.fill", assetName: "icon-settings",
                                        size: 14, fill: .white, stroke: Color(hex: "E40063"))
                                .frame(width: 44, height: 44)
                        }
                        .glassButton()
                    }
                    Spacer()
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
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
            .sussDrawerDim(showSettings)
            .sheet(isPresented: $showSettings) {
                SettingsView(onClose: { showSettings = false })
            }
        }
    }
}

#Preview {
    RoomSetupView(vm: GameViewModel())
}
