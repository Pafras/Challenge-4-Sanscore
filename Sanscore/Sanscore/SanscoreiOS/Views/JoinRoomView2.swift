// JoinRoomView2.swift
// Screen 2b — Room list + code entry. Shows "JOINNN ROOOOM" header + discovered
// nearby rooms as buttons. Tapping a room slides up an inline code-entry card
// (4-digit numpad) instead of a system alert.
//
// OWNER: Agung. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)
import MultipeerConnectivity
import UIKit

struct JoinRoomView2: View {
    let vm: GameViewModel
    let dismissAll: () -> Void
    @State private var selected: MCPeerID?
    @State private var showCodeEntry = false
    @State private var digits: [String] = ["", "", "", ""]
    @State private var focusIndex = 0

    var body: some View {
        ZStack {
            Image("pink-bg")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("join-room")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 340)
                    .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(vm.room.foundRooms, id: \.self) { host in
                            Button {
                                selected = host
                                resetCode()
                                vm.joinError = nil   // fresh card, no stale warning
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showCodeEntry = true
                                }
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

            // Code entry overlay
            if showCodeEntry {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCodeEntry = false
                        }
                        selected = nil
                    }

                VStack {
                    Spacer()
                    codeEntryCard
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    vm.room.stopBrowsing()
                    dismissAll()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Code Entry Card

    private var codeEntryCard: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Image("enter-code")
                .resizable()
                .scaledToFit()
                .frame(width: 260)

            // 4 digit boxes
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        .white.opacity(i == focusIndex ? 0.6 : 0.2),
                                        lineWidth: 2
                                    )
                            )

                        if digits[i].isEmpty && i == focusIndex {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white)
                                .frame(width: 2, height: 30)
                        } else {
                            Text(digits[i])
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 65, height: 72)
                }
            }
            .padding(.horizontal, 24)

            // Wrong-code warning. Stays on the card; user retypes.
            if let err = vm.joinError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 24)
            }

            numpadView
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        // A failed code buzzes + clears the boxes so the player can retype.
        .onChange(of: vm.joinError) { _, err in
            if err != nil {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                resetCode()
            }
        }
    }

    // MARK: - Numpad

    private var numpadView: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]
        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(height: 50)
                        } else {
                            Button {
                                handleKey(key)
                            } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(systemName: "delete.backward")
                                            .font(.title2.weight(.semibold))
                                    } else {
                                        Text(key)
                                            .font(.system(size: 24, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    .white.opacity(0.85),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Input Logic

    private func handleKey(_ key: String) {
        vm.joinError = nil   // clear any previous warning as they retype
        if key == "⌫" {
            if focusIndex > 0 && digits[focusIndex].isEmpty {
                focusIndex -= 1
            }
            digits[focusIndex] = ""
        } else {
            digits[focusIndex] = key
            if focusIndex < 3 {
                focusIndex += 1
            } else {
                let fullCode = digits.joined()
                if fullCode.count == 4, let host = selected {
                    // Invite but STAY on the card. Correct code -> we connect and
                    // the view switches to the identity screen. Wrong code ->
                    // vm.joinError fills in and the digits reset for a retry
                    // (see .onChange in codeEntryCard). Don't close the card here.
                    vm.join(host, code: fullCode)
                }
            }
        }
    }

    private func resetCode() {
        digits = ["", "", "", ""]
        focusIndex = 0
    }
}

#Preview {
    NavigationStack {
        JoinRoomView2(vm: GameViewModel(), dismissAll: {})
    }
}
#endif
