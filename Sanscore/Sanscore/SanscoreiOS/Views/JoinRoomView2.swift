// JoinRoomView2.swift
// Screen 2b — Room list. Shows "JOINNN ROOOOM" header + discovered nearby
// rooms as buttons. Tapping a room prompts for the 4-digit code, then joins.
//
// OWNER: Agung. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)
import MultipeerConnectivity

struct JoinRoomView2: View {
    let vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: MCPeerID?
    @State private var code = ""

    var body: some View {
        ZStack {
            Image("pink-bg")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // "JOINNN ROOOOM" header
                Image("join-room")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 340)
                    .padding(.top, 20)

                // Room list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(vm.room.foundRooms, id: \.self) { host in
                            Button {
                                selected = host
                            } label: {
                                Text(vm.room.roomNames[host] ?? host.displayName)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.glass)
                            .tint(.pink)
                            .padding(.horizontal, 32)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    vm.room.stopBrowsing()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .alert("Enter room code", isPresented: .constant(selected != nil)) {
            TextField("4-digit code", text: $code)
                .keyboardType(.numberPad)
            Button("Join") {
                if let host = selected { vm.join(host, code: code) }
                code = ""; selected = nil
            }
            Button("Cancel", role: .cancel) { code = ""; selected = nil }
        }
    }
}

#Preview {
    NavigationStack {
        JoinRoomView2(vm: GameViewModel())
    }
}
#endif
