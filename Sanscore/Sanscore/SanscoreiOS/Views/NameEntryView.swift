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
                IdentityTitle(text: "WHAT'S\nYOUR NAME", size: 44, tilt: -4)
                    .padding(.top, 44)

                Spacer()

                // The name field — big, white, centred (see mockup).
                TextField("", text: $name)
                    .focused($focused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 44, weight: .bold))
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
                // Back = abandon the create/join (leaves room), return home.
                Button { vm.cancelIdentity() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.pink)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 8)
            }
        }
        .onAppear { focused = true }   // pop the keyboard immediately
    }

    private func done() {
        guard !trimmed.isEmpty else { return }
        vm.finishNameEntry(trimmed)
    }
}

#Preview {
    NameEntryView(vm: GameViewModel())
}
#endif
