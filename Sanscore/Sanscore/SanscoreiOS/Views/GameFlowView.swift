// GameFlowView.swift
// Real UI: room setup -> lobby -> roulette role reveal -> push-to-talk
// asker/answerer (or spectating) -> calculating -> result. Reads
// GameViewModel.state and switches screens. Computes nothing itself — all
// math + LLM calls stay in GameViewModel/SusEngine.
//
// OWNER: Pafras (iOS). The app's real screen (replaces the old DevTestView).

import SwiftUI
import Combine
#if os(iOS)
import MultipeerConnectivity
#endif

struct GameFlowView: View {
    @State private var vm = GameViewModel()   // all mocks by default

    var body: some View {
        VStack {
            switch vm.state {
            case .idle:
                RoomSetupView(vm: vm)
            case .calibrating:
                CalibratingView(prompt: vm.calibrationPrompt,
                                step: vm.calibrationStep + 1,
                                total: vm.calibrationPrompts.count,
                                onPress: { vm.calibrationPressed() },
                                onRelease: { vm.calibrationReleased() })
            case .roomLobby:
                RoomLobbyView(vm: vm)
            case .roleReveal:
                RoleRevealView()
            case .asking:
                AskingView(onPress: { vm.askerPressed() },
                           onRelease: { vm.askerReleased() })
            case .answering:
                AnsweringView(onPress: { vm.answererPressed() },
                              onRelease: { vm.answererReleased() })
            case .spectating:
                SpectatingView { vm.backToStart() }
            case .waitingForResult:
                WaitingForResultView { vm.backToStart() }
            case .loading:
                LoadingView()
            case .calculating:
                CalculatingView()
            case .result:
                if let result = vm.lastResult {
                    ResultView(result: result,
                               canAdvance: vm.canAdvance) { vm.nextRound() }
                }
            }
        }
        .animation(.default, value: vm.state)
        .overlay(alignment: .top) {
            if let notice = vm.leftNotice {
                Label(notice, systemImage: "person.fill.xmark")
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: vm.leftNotice)
    }
}

private struct RoomSetupView: View {
    @Bindable var vm: GameViewModel
    @State private var showBrowser = false
    @State private var showEditProfile = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "face.smiling")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Sanscore")
                .font(.largeTitle.bold())
            Text("Entertainment only — not a real lie detector.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let alert = vm.roomAlert {
                Label(alert, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Text("Playing as \(vm.playerName)")
                .font(.subheadline)
            Button("Edit profile") { showEditProfile = true }
                .buttonStyle(.bordered)
            if vm.isCalibrated {
                Label("Your normal: \(Int(vm.baseline.heartRate)) BPM", systemImage: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            Button(vm.isCalibrated ? "Recalibrate" : "Calibrate (set your normal)") {
                vm.startCalibration()
            }
            .buttonStyle(.bordered)
            Button("Create room") { vm.createRoom() }
                .buttonStyle(.borderedProminent)
            Button("Join room") {
                vm.startBrowsing()
                showBrowser = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        #if os(iOS)
        .task {
            // Ask mic + speech permission up front so the answer round doesn't
            // silently fail. Harmless no-op with MockSpeech.
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

#if os(iOS)
// Custom nearby-rooms picker: shows found hosts by name, asks for the code,
// then joins. Replaces MCBrowserViewController so we can gate on the code.
private struct JoinRoomView: View {
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
#endif

private struct RoomLobbyView: View {
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

#if os(iOS)
// Tap-your-bubble editor: photo (take/retake) + name. Name can change any time
// (even mid-lobby) — it's a display label broadcast to the room, not the network
// identity, so no reconnect.
private struct EditProfileView: View {
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
#endif

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

private struct RoleRevealView: View {
    @State private var flicker = false

    var body: some View {
        Rectangle()
            .fill(flicker ? .blue : .green)
            .ignoresSafeArea()
            .task {
                while true {
                    try? await Task.sleep(for: .milliseconds(120))
                    flicker.toggle()
                }
            }
    }
}

// Full-screen push-to-talk. Hold to talk, release fires onRelease.
// enabled = false greys it out and ignores presses (e.g. no question typed yet).
private struct PushToTalkView: View {
    let label: String
    let subtitle: String
    let color: Color
    var enabled: Bool = true
    var onPress: (() -> Void)? = nil
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(isPressed ? .white.opacity(0.8) : .secondary)
                Text(label)
                    .font(.title2.bold())
                    .foregroundStyle(isPressed ? .white : .primary)
                    .multilineTextAlignment(.center)
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isPressed ? .white : color)
            }
            Spacer()
            Text(isPressed ? "Release when done" : "Hold anywhere to talk")
                .font(.caption)
                .foregroundStyle(isPressed ? .white.opacity(0.8) : .secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isPressed ? color : color.opacity(0.12))
        .opacity(enabled ? 1 : 0.4)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard enabled else { return }
                    if !isPressed {
                        isPressed = true
                        onPress?()
                    }
                }
                .onEnded { _ in
                    guard enabled else { return }
                    isPressed = false
                    onRelease()
                }
        )
    }
}

private struct AskingView: View {
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: "Ask your question out loud",
                       subtitle: "You're asking",
                       color: .blue,
                       onPress: onPress,
                       onRelease: onRelease)
    }
}

private struct AnsweringView: View {
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: "Say your answer",
                       subtitle: "You're answering",
                       color: .green,
                       onPress: onPress,
                       onRelease: onRelease)
    }
}

private struct CalibratingView: View {
    let prompt: String
    let step: Int
    let total: Int
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: prompt,
                       subtitle: "Calibrating \(step) of \(total) — this is your normal",
                       color: .purple,
                       onPress: onPress,
                       onRelease: onRelease)
    }
}

private struct SpectatingView: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Watching this round…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button("Back", action: onCancel)
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .ignoresSafeArea()
    }
}

private struct WaitingForResultView: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Waiting for the answer…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Back", action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

private struct LoadingView: View {
    // Keep in sync with RealHeartRate.sampleWindow.
    private let captureSeconds = 8

    @State private var trim: CGFloat = 1        // ring drains 1 -> 0
    @State private var remaining = 8            // countdown number
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.red.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: trim)
                    .stroke(.red, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))   // start at top
                Text("\(remaining)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .frame(width: 180, height: 180)

            Text("Keep your finger on the back camera")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Cover the rear camera + flash — that's how we read your heartbeat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .onAppear {
            trim = 1
            remaining = captureSeconds
            withAnimation(.linear(duration: Double(captureSeconds))) { trim = 0 }
        }
        .onReceive(tick) { _ in
            if remaining > 0 { withAnimation { remaining -= 1 } }
        }
    }
}

private struct CalculatingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Calculating your answer…")
                .font(.title3.bold())
            Text("The judge is thinking…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

private struct ResultView: View {
    let result: SusResult
    var canAdvance: Bool
    var onNext: () -> Void

    private var bandColor: Color {
        switch result.band {
        case .truth: return .green
        case .hmm:   return .yellow
        case .liar:  return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verdict")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(result.band.label)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(bandColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color.green.frame(width: geo.size.width * 0.35)
                        Color.yellow.frame(width: geo.size.width * 0.25)
                        Color.red.frame(width: geo.size.width * 0.40)
                    }
                    .clipShape(Capsule())
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: 18)
                        .offset(x: geo.size.width * result.score - 1)
                }
            }
            .frame(height: 10)

            HStack {
                Text("Truth")
                Spacer()
                Text("Hmm")
                Spacer()
                Text("Liar")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(result.verdict)
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()
            if canAdvance {
                Button("Next round", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Waiting for the host to start the next round…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

#Preview {
    GameFlowView()
}
