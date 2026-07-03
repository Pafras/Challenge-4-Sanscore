// GameRoomView.swift
// Screen 5 — the room / lobby (Figma: "Game room" — ROOM 0347, avatar bubbles,
// "waiting for host", START). Shown on GameState.roomLobby. Contains the drifting
// player bubbles.
//
// OWNER: Agung. Style to Figma (dark room, colored avatar bubbles, START).
// LAYOUT ONLY — call existing vm methods, never edit GameViewModel.
// See HANDOFF-UI.md.
//
// (RoomLobbyView is module-internal so the root switch sees it. The two bubble
// helpers stay `private` — only used inside this file.)

import SwiftUI

struct RoomLobbyView: View {
    let vm: GameViewModel
    @State private var showEditProfile = false
    @State private var showLeaveConfirm = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showLeaveConfirm = true
                } label: {
                    Label("Leave", systemImage: "chevron.left")
                }
                Spacer()
            }
            Text("Room ready")
                .font(.title2.bold())
            if let alert = vm.roomAlert {
                Label(alert, systemImage: "info.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            if vm.room.isHost {
                VStack(spacing: 2) {
                    Text("Room code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.room.roomCode)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            // Players float as bubbles (avatar or initials). Tap your own to
            // edit your photo + name.
            PlayerBubblesView(players: vm.room.players, avatars: vm.avatars,
                              displayNames: vm.displayNames, me: vm.myName) { showEditProfile = true }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Tap your bubble to edit your photo and name")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Host starts; joiners wait for the host's turn assignment.
            if vm.room.isHost {
                Button(vm.room.connectedPeers.isEmpty ? "Start (solo)" : "Start") { vm.start() }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Waiting for the host to start…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            #if DEBUG
            VStack(spacing: 8) {
                Text("Dev: force role (solo screen test)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Asker") { vm.forceRole(.asker) }
                    Button("Answerer") { vm.forceRole(.answerer) }
                    Button("Spectator") { vm.forceRole(.spectator) }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding(.top, 8)
            #endif
        }
        .padding()
        .confirmationDialog(
            vm.room.isHost ? "Close the room?" : "Leave the room?",
            isPresented: $showLeaveConfirm, titleVisibility: .visible
        ) {
            Button(vm.room.isHost ? "Close room" : "Leave", role: .destructive) {
                vm.leaveRoom()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(vm.room.isHost
                 ? "Leaving closes the room for everyone."
                 : "You'll leave the room and return to the start.")
        }
        #if os(iOS)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(vm: vm)
        }
        #endif
    }
}

// Player avatars drifting as bubbles. Gentle sine float per bubble; avatar photo
// or initials fallback. Your own bubble is ringed.
private struct PlayerBubblesView: View {
    let players: [String]
    let avatars: [String: Data]
    let displayNames: [String: String]
    let me: String
    var onTapMe: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ForEach(Array(players.enumerated()), id: \.element) { index, name in
                    BubbleView(label: displayNames[name] ?? name, image: avatars[name], isMe: name == me)
                        .position(position(index: index, count: players.count, size: geo.size, t: t))
                        .onTapGesture { if name == me { onTapMe() } }
                }
            }
        }
    }

    // Spread bubbles across a row (wrapping), plus a slow sine drift per bubble.
    private func position(index: Int, count: Int, size: CGSize, t: Double) -> CGPoint {
        let perRow = max(1, Int((size.width / 110).rounded(.down)))
        let row = index / perRow
        let col = index % perRow
        let rowsUsed = (count + perRow - 1) / perRow
        let cellW = size.width / CGFloat(perRow)
        let cellH = min(140, size.height / CGFloat(max(1, rowsUsed)))
        let baseX = cellW * (CGFloat(col) + 0.5)
        let baseY = cellH * (CGFloat(row) + 0.5) + (size.height - cellH * CGFloat(rowsUsed)) / 2
        let phase = Double(index) * 1.3
        let driftX = CGFloat(sin(t * 0.7 + phase)) * 12
        let driftY = CGFloat(cos(t * 0.5 + phase)) * 12
        return CGPoint(x: baseX + driftX, y: baseY + driftY)
    }
}

private struct BubbleView: View {
    let label: String
    let image: Data?
    let isMe: Bool

    private var initials: String {
        String(label.split(separator: " ").compactMap(\.first).prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(.tint.opacity(0.15))
                #if os(iOS)
                if let image, let ui = UIImage(data: image) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials).font(.title3.bold()).foregroundStyle(.tint)
                }
                #else
                Text(initials).font(.title3.bold()).foregroundStyle(.tint)
                #endif
            }
            .frame(width: 72, height: 72)
            .overlay(Circle().stroke(isMe ? Color.accentColor : .clear, lineWidth: 3))
            .overlay(alignment: .bottomTrailing) {
                if isMe {
                    Image(systemName: "camera.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .background(Circle().fill(.background))
                }
            }

            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .frame(maxWidth: 84)
        }
    }
}

#Preview {
    RoomLobbyView(vm: GameViewModel())
}
