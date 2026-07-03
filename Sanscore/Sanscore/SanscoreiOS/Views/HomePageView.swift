// HomePageView.swift
// Screen 1 — the home/landing screen (Figma: "Homepage"). SUSS meter title +
// JOIN + Create Room. Shown on GameState.idle.
//
// OWNER: Marleen. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.
//
// (Struct name stays RoomSetupView so the root switch in GameFlowView keeps
// working; it's module-internal now, not `private`, so the switch can see it.)

import SwiftUI

struct RoomSetupView: View {
    @Bindable var vm: GameViewModel
    @State private var showBrowser = false
    @State private var showEditProfile = false

    private let hotPink = Color(red: 1.0, green: 0.357, blue: 0.812)
    private let mintGreen = Color(red: 0.65, green: 0.9, blue: 0.75)

    var body: some View {
        ZStack {
            hotPink.ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title
                VStack(spacing: -4) {
                    Text("SUSS")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 0.0, green: 0.7, blue: 1.0),
                                                    Color(red: 0.2, green: 0.4, blue: 1.0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .cyan.opacity(0.6), radius: 8, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 2, y: 3)

                    Text("meter")
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .italic()
                        .foregroundStyle(hotPink.opacity(0.7))
                        .shadow(color: .white.opacity(0.4), radius: 1, x: -1, y: -1)
                }

                Spacer()

                // Alert (room closed, etc.)
                if let alert = vm.roomAlert {
                    Label(alert, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.black.opacity(0.3), in: Capsule())
                        .padding(.bottom, 12)
                }

                // JOIN button
                Button {
                    vm.startBrowsing()
                    showBrowser = true
                } label: {
                    Text("JOIN")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 1, y: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(colors: [mintGreen.opacity(0.8), mintGreen],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 14)

                // Create Room button
                Button {
                    vm.createRoom()
                } label: {
                    Text("Create Room")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(hotPink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        )
                }
                .padding(.horizontal, 40)

                // Secondary actions row
                HStack(spacing: 16) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Label(vm.playerName, systemImage: "person.circle.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.white)
                    }

                    if vm.isCalibrated {
                        Label("\(Int(vm.baseline.heartRate)) BPM", systemImage: "heart.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Button(vm.isCalibrated ? "Recalibrate" : "Calibrate") {
                        vm.startCalibration()
                    }
                    .font(.footnote.bold())
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 16)

                Text("Entertainment only — not a real lie detector.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
        }
        #if os(iOS)
        .task {
            _ = await RealSpeechCapture.requestPermission()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(vm: vm)
        }
        .sheet(isPresented: $showBrowser) {
            JoinRoomView(vm: vm)
        }
        #endif
    }
}

#Preview {
    RoomSetupView(vm: GameViewModel())
}
