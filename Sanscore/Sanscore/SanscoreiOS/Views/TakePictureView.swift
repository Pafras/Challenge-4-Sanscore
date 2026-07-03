// TakePictureView.swift
// Screen 3 — identity / take a photo (Figma: "Take a picture" / "MAKE YOUR
// IDENTITY"). Photo (take/retake) + name. Name can change any time (even
// mid-lobby) — it's a display label broadcast to the room, not the network
// identity, so no reconnect.
//
// OWNER: Agung. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.
//
// NOTE: today this is shown as a sheet from Home/Lobby. Figma wants it as a
// full step BEFORE the room. Re-ordering the flow = new GameState + vm method =
// Pafras's job. You just build the layout; Pafras wires the flow later.
// (Struct name stays EditProfileView so the sheets keep working.)

import SwiftUI
#if os(iOS)

struct EditProfileView: View {
    @Bindable var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    Button {
                        showCamera = true
                    } label: {
                        Label(vm.avatars[vm.myName] == nil ? "Take photo" : "Retake photo",
                              systemImage: "camera.fill")
                    }
                }
                Section("Name") {
                    TextField("Your name", text: $name)
                }
            }
            .navigationTitle("Edit profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        vm.setDisplayName(name)
                        dismiss()
                    }
                }
            }
            .onAppear { name = vm.playerName }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in vm.setMyAvatar(image) }
            }
        }
    }
}

#Preview {
    EditProfileView(vm: GameViewModel())
}
#endif
