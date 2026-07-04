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

    private var roomPill: some View {
        VStack(spacing: 0) {
            Text("ROOM").font(.system(size: 12, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.85))
            Text(vm.room.roomCode).font(.system(size: 30, weight: .black)).fontWidth(.expanded)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 2))
    }

    private var countBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.2.fill")
            Text("\(vm.room.players.count)")
        }
        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 2))
    }

    var body: some View {
        ZStack {
            // Dark "box of balls" room.
            Color.black.ignoresSafeArea()
            CheckeredBackground().ignoresSafeArea()

            // Player avatars as physics balls (fall from top, bounce, tilt/shake).
            #if os(iOS)
            PlayerBubblesPhysics(players: vm.room.players, avatars: vm.avatars,
                                 me: vm.myName) { showEditProfile = true }
                .ignoresSafeArea()
            #endif

            VStack(spacing: 12) {
                // Top bar: close (X) · ROOM code pill · player count.
                HStack(alignment: .center) {
                    Button { showLeaveConfirm = true } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.18)))
                    }
                    Spacer()
                    roomPill
                    Spacer()
                    countBadge
                }

                if let alert = vm.roomAlert {
                    Label(alert, systemImage: "info.circle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Host CTA = START; player CTA = wait + loading bars.
                if vm.room.isHost {
                    Button { vm.start() } label: {
                        Text("START")
                            .font(.system(size: 26, weight: .black)).fontWidth(.expanded)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Capsule().fill(.white.opacity(0.14)))
                            .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 2))
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Waiting for host to start the game")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        LoadingBars()
                    }
                    .padding(.bottom, 8)
                }

                #if DEBUG
                HStack(spacing: 8) {
                    Button("Asker") { vm.forceRole(.asker) }
                    Button("Answerer") { vm.forceRole(.answerer) }
                    Button("Spectator") { vm.forceRole(.spectator) }
                }
                .buttonStyle(.bordered).font(.caption).tint(.white)
                #endif
            }
            .padding()
        }
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
