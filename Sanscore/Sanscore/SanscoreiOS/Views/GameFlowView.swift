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
                    ResultView(result: result) { vm.nextRound() }
                }
            }
        }
        .animation(.default, value: vm.state)
    }
}

private struct RoomSetupView: View {
    let vm: GameViewModel
    @State private var showBrowser = false

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
            Spacer()
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
                    Button(host.displayName) { selected = host }
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

    var body: some View {
        VStack(spacing: 16) {
            Text("Room ready")
                .font(.title2.bold())
            if vm.room.isHost {
                VStack(spacing: 2) {
                    Text("Room code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.room.roomCode)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Text("Share this code with players")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if vm.room.connectedPeers.isEmpty {
                Text("Waiting for players to join…")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.room.connectedPeers, id: \.self) { peer in
                    Label(peer, systemImage: "person.fill")
                }
            }
            Spacer()
            // Host starts the game; joiners wait for the host's turn assignment.
            if vm.room.isHost || vm.room.connectedPeers.isEmpty {
                Button("Start") { vm.start() }
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
            Button("Next round", action: onNext)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

#Preview {
    GameFlowView()
}
