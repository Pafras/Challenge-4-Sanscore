// GameFlowView.swift
// Real UI: room setup -> lobby -> roulette role reveal -> push-to-talk
// asker/answerer (or spectating) -> calculating -> result. Reads
// GameViewModel.state and switches screens. Computes nothing itself — all
// math + LLM calls stay in GameViewModel/SusEngine.
//
// OWNER: Pafras (iOS). The app's real screen (replaces the old DevTestView).

import SwiftUI

struct GameFlowView: View {
    @State private var vm = GameViewModel()   // all mocks by default

    var body: some View {
        VStack {
            switch vm.state {
            case .idle, .calibrating:
                RoomSetupView(vm: vm)
            case .roomLobby:
                RoomLobbyView(vm: vm)
            case .roleReveal:
                RoleRevealView()
            case .asking:
                AskingView { vm.askerReleased() }
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
            Button("Create room") { vm.createRoom() }
                .buttonStyle(.borderedProminent)
            Button("Join room") { showBrowser = true }
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
            RoomBrowserView(room: vm.room)
                .onDisappear { vm.joinRoom() }
        }
        #endif
    }
}

private struct RoomLobbyView: View {
    let vm: GameViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Room ready")
                .font(.title2.bold())
            if vm.room.connectedPeers.isEmpty {
                Text("Waiting for players to join…")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.room.connectedPeers, id: \.self) { peer in
                    Label(peer, systemImage: "person.fill")
                }
            }
            Spacer()
            Button("Start") { vm.startSession() }
                .buttonStyle(.borderedProminent)
            #if DEBUG
            VStack(spacing: 8) {
                Text("Dev: force role")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Asker") { vm.startSession(forcedRole: .asker) }
                    Button("Answerer") { vm.startSession(forcedRole: .answerer) }
                    Button("Spectator") { vm.startSession(forcedRole: .spectator) }
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
    let onRelease: () -> Void

    var body: some View {
        PushToTalkView(label: "Ask your question out loud",
                       subtitle: "You're asking",
                       color: .blue,
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
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Reading heart rate, timing, tone…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
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
