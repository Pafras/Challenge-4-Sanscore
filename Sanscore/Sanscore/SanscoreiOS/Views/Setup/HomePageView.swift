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

                VStack(spacing: 16) {
                    Spacer()

                    // Logo — centered in upper half
                    Image("sus-meter-new")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)

                    // JOIN — design-system button built in code (like setup
                    // profile). No glisten on the homepage — the beam is only
                    // for the lobby JOIN + game-room START.
                    Button {
                        vm.startBrowsing()
                        showBrowser = true
                    } label: {
                        IdentityTitle(text: "JOIN", size: 26, strokeWidth: 4,
                                      fill: .white, stroke: Color(hex: "E40063"), tilt: 0)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.suss)
                    .padding(.horizontal, 20)   // design screen margin

                    // CREATE — same system, pink-gradient variant.
                    Button {
                        vm.createRoom()
                    } label: {
                        IdentityTitle(text: "CREATE", size: 26, strokeWidth: 4,
                                      fill: .white, stroke: Color(hex: "E40063"), tilt: 0)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(SussButtonStyle(
                        gradientColors: [Color(hex: "FFC1EB"), Color(hex: "EB0067")]))
                    .padding(.horizontal, 20)   // design screen margin

                    Spacer()
                }

                // Settings gear — design-system action button, top-right.
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            AudioManager.shared.playSFX(.click)
                            showSettings = true
                        } label: {
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
                SettingsView(onClose: { showSettings = false }, vm: vm)
            }
        }
    }
}

#Preview {
    RoomSetupView(vm: GameViewModel())
}
