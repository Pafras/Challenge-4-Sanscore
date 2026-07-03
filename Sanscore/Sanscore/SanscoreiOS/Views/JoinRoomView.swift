// JoinRoomView.swift
// Screen 2 — enter room code (Figma: "Join Room" / "ENTER ROOM CODE" numpad).
// Custom nearby-rooms picker: shows found hosts by name, asks for the code,
// then joins. Replaces MCBrowserViewController so we can gate on the code.
//
// OWNER: Marleen. Style to Figma (the numpad + code boxes). LAYOUT ONLY — call
// existing vm methods, never edit GameViewModel. See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)
import MultipeerConnectivity

struct JoinRoomView: View {
    let vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: MCPeerID?
    @State private var code = ""

    var body: some View {
        NavigationStack {
            List {
                if vm.room.foundRooms.isEmpty {
                    Text("Looking for nearby rooms…")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.room.foundRooms, id: \.self) { host in
                    Button(vm.room.roomNames[host] ?? host.displayName) { selected = host }
                }
            }
            .navigationTitle("Join a room")
            .alert("Enter room code", isPresented: .constant(selected != nil)) {
                TextField("4-digit code", text: $code)
                    .keyboardType(.numberPad)
                Button("Join") {
                    if let host = selected { vm.join(host, code: code) }
                    code = ""; selected = nil
                    dismiss()
                }
                Button("Cancel", role: .cancel) { code = ""; selected = nil }
            }
        }
    }
}

#Preview {
    JoinRoomView(vm: GameViewModel())
}
#endif
