// GameViewModel.swift
// The bridge between logic and UI. Holds the game state + the numbers the
// screens show. Calls the logic. Owns nothing hardware-specific — it only
// talks to the protocols, so it never changes when mocks become real modules.
//
// The UI reads vm.state, vm.myRole, vm.lastResult, vm.verdict and does NOT
// compute anything. All math lives here or in SusEngine.
//
// OWNER: Pafras.

import Foundation
import Observation
import UIKit
import MultipeerConnectivity

@Observable
final class GameViewModel {
    // --- State the UI watches ---
    var state: GameState = .idle
    var myRole: PlayerRole = .spectator
    var lastResult: SusResult?
    // ponytail: the asker only speaks the question out loud (push-to-talk,
    // no typing) — nothing captures its text yet, so this stays "". Fine for
    // Mock testing since StructureAnalyzing doesn't need it; the real LLM
    // (StructureAnalyzer) will need the asker's question transcribed too.
    var currentQuestion: String = ""

    // --- Real room networking (create/join + result broadcast). ---
    // ponytail: connect + broadcast results is real. Turn-order (who's asker,
    // who's answerer, round number) is NOT synced over the room yet — each
    // device rolls its own role locally in startSession(). Wire that through
    // RoomService once multi-device turn-order is built (see RoomService.swift).
    let room: RoomService

    // --- Per-player baseline from the calibration round ---
    // ponytail: default baseline lets the app run before calibration is built.
    // TODO(marleen): fill this from the real calibration round (2-3 easy Qs).
    var baseline = Baseline(heartRate: 72, responseTime: 2.0, speechRate: 2.2)
    // --- The engine + the swappable capture modules ---
    private let engine: SusEngine
    private let heart: HeartRateSource
    private let speech: SpeechCapturing
    private let structure: StructureAnalyzing

    // When the response-time clock started (set the moment the asker lets go).
    private var responseClockStart: Date?
    private var measuredResponseTime: Double = 0

    // Inject anything conforming to the protocols. Swap mocks -> real ONE at a
    // time, testing on a real device after each (see CLAUDE.md "Sensor swap").
    // Step 1 DONE: speech is real. Step 2/3 (heart, structure) still mock.
    // NOTE: RealSpeechCapture needs a real iPhone — it won't transcribe in the
    // Simulator. Put MockSpeech() back here if you need to demo on Simulator.
    init(engine: SusEngine = SusEngine(),
         heart: HeartRateSource = MockHeartRate(),
         speech: SpeechCapturing = RealSpeechCapture(),
         structure: StructureAnalyzing = MockStructure()) {
        self.engine = engine
        self.heart = heart
        self.speech = speech
        self.structure = structure
        self.room = RoomService(displayName: UIDevice.current.name)
        self.room.onReceive = { [weak self] result in self?.receivedResult(result) }
    }

    // A RoundResult arrived from the answerer's phone. Only asker (waiting)
    // and spectators (watching) act on it — the answerer already scored
    // itself locally in runRound().
    private func receivedResult(_ result: RoundResult) {
        guard state == .waitingForResult || state == .spectating else { return }
        lastResult = SusResult(score: result.score, band: SusBand(score: result.score), verdict: result.verdict)
        state = .result
    }

    // --- Room setup ---

    // "Create room" — become host, accept joiners.
    func createRoom() {
        room.startHosting()
        state = .roomLobby
    }

    // "Join room" — the view presents RoomBrowserView (MCBrowserViewController)
    // as a sheet; this just moves the state forward once that sheet is done.
    func joinRoom() {
        state = .roomLobby
    }

    // Host (or solo dev testing) tapped "start". Roulette animation, then
    // this device's role for the round gets picked.
    // forcedRole lets #if DEBUG dev buttons skip the coin flip for testing.
    // Real play always passes nil (random).
    func startSession(forcedRole: PlayerRole? = nil) {
        lastResult = nil
        state = .roleReveal
        Task {
            try? await Task.sleep(for: .seconds(2))
            myRole = forcedRole ?? [.asker, .answerer, .spectator].randomElement()!
            switch myRole {
            case .asker:
                currentQuestion = ""   // the asker types their own question next
                state = .asking
            case .answerer:
                responseClockStart = Date()
                state = .answering
            case .spectator:
                state = .spectating
            }
        }
    }

    // --- Push-to-talk ---

    // Asker held the whole screen while reading the question out loud, then
    // let go. Now waits for the answerer's phone to score the round and
    // broadcast a RoundResult back (see receivedResult).
    // ponytail: the release itself isn't sent to the answerer's phone yet —
    // there's no turn-order sync (see RoomService.swift). Solo/no-partner
    // testing will sit on this screen forever; test the answerer role instead.
    func askerReleased() {
        state = .waitingForResult
    }

    // Escape hatch for .waitingForResult and .spectating — neither resolves
    // without a real partner device broadcasting a RoundResult back (see
    // askerReleased / receivedResult). Bails out to the start screen.
    func backToStart() {
        state = .idle
    }

    // Answerer pressed down to start talking — stop the response-time clock
    // and start capturing audio right now.
    func answererPressed() {
        measuredResponseTime = Date().timeIntervalSince(responseClockStart ?? Date())
        try? speech.startListening()
    }

    // Answerer let go — stop capturing, score the round, broadcast the
    // result to the room so the asker + spectators can leave their waiting
    // screens.
    func answererReleased() {
        Task {
            await runRound(responseTime: measuredResponseTime)
        }
    }

    // Gather all signals, run the LLM, fuse, show the result, and broadcast
    // it to the room. Only the answerer calls this — responseTime is
    // measured from the press-to-talk timestamps in answererPressed().
    private func runRound(responseTime: Double) async {
        state = .loading   // reading heart rate + transcribing speech
        let speechResult = await speech.stopAndTranscribe()
        let bpm = await heart.currentBPM()

        state = .calculating   // the LLM judges the answer + fuses the score
        // The LLM is the only step that can fail; fall back to neutral 0.5.
        let structureResult: StructureResult
        if speechResult.text.isEmpty {
            structureResult = StructureResult(score: 0.5, verdict: "Couldn't hear you — say that again louder.")
        } else {
            structureResult = (try? await structure.analyze(question: currentQuestion, answer: speechResult.text))
                ?? StructureResult(score: 0.5, verdict: "The judge shrugged.")
        }

        let signals = Signals(heartRate: bpm,
                              responseTime: responseTime,
                              speechRate: speechResult.speechRate,
                              answerText: speechResult.text)

        var result = engine.score(signals: signals, baseline: baseline, structureScore: structureResult.score)
        result.verdict = structureResult.verdict   // the LLM writes the funny line
        lastResult = result
        state = .result

        room.broadcast(RoundResult(answererName: room.myPeerID.displayName, score: result.score, verdict: result.verdict))
    }

    // "Next round" — roll again without leaving the room.
    func nextRound() {
        startSession()
    }
}
