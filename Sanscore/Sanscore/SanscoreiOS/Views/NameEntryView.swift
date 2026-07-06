// NameEntryView.swift
// "What's your name" — name entry shown BEFORE the identity photo:
//   host  -> after Create room
//   joiner-> after the correct code is accepted
// DONE saves the display name (vm.finishNameEntry) and advances to the photo.
// Matches Satria's mockup (blue bg, pink stroked title, big centred field, DONE).
//
// OWNER: Pafras (wired into the flow). Reads vm, computes nothing.

import SwiftUI
#if os(iOS)

struct NameEntryView: View {
    @Bindable var vm: GameViewModel
    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            Image("blue-bg")
                .resizable()
                .ignoresSafeArea()

            VStack {
                IdentityTitle(text: "WHAT'S\nYOUR NAME", size: 38, tilt: 0)   // flat, no lean
                    .padding(.top, 44)

                Spacer()

                // The name field — big, white, centred (see mockup).
                TextField("", text: $name)
                    .focused($focused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 56, weight: .bold))   // bigger than the title
                    .foregroundStyle(.white)
                    .tint(.white)                 // white cursor
                    .submitLabel(.done)
                    .onSubmit(done)
                    .padding(.horizontal, 24)

                Spacer()

                HStack {
                    Spacer()
                    Button(action: done) {
                        Text("DONE")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(trimmed.isEmpty ? .white.opacity(0.6) : .pink)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                    .disabled(trimmed.isEmpty)
                    .padding(.trailing, 24)
                }
                .padding(.bottom, 16)
            }
            .overlay(alignment: .topLeading) {
                // Close = abandon the create/join (leaves room), return home.
                // X for consistency with the identity screens.
                Button { vm.cancelIdentity() } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.pink)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 8)
            }
        }
        // Pop the keyboard AFTER the screen transition settles. Focusing in
        // onAppear races the root switch's state animation — the field grabs
        // focus mid-transition and the keyboard never shows (Simulator
        // reproduces it reliably).
        .task {
            try? await Task.sleep(for: .seconds(0.5))
            focused = true
        }
    }

    private func done() {
        guard !trimmed.isEmpty else { return }
        // Drop focus FIRST so the keyboard dismisses with this screen instead
        // of lingering over the photo screen for a beat.
        focused = false
        vm.finishNameEntry(trimmed)
    }
}

#Preview {
    NameEntryView(vm: GameViewModel())
}
#endif
