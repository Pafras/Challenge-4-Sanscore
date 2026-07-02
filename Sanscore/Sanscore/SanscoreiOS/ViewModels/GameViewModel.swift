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
    // Step 1 DONE: speech real. Step 2 DONE: heart real. Step 3: structure/LLM
    // still mock — swap to StructureAnalyzer() once Agung's tuning is merged.
    // NOTE: real speech + heart need a real iPhone — they won't work in the
    // Simulator. Put the Mock* back here if you need to demo on Simulator.
    init(engine: SusEngine = SusEngine(),
         heart: HeartRateSource = RealHeartRate(),
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

    // --- Calibration ---
    // Capture the player's OWN normal (heart rate, speech rate, response time)
    // by averaging 3 easy answers, so the sus score measures deviation from
    // THEM, not from hardcoded numbers. Set once before playing; reused rounds.
    var isCalibrated = false

    let calibrationPrompts = [
        "Say your name and what you had for breakfast",
        "Count out loud from one to ten",
        "Describe what you did yesterday"
    ]
    private(set) var calibrationPrompt = ""
    private(set) var calibrationStep = 0        // 0-based; UI shows +1

    // Captures accumulated across the 3 prompts, averaged at the end.
    private var calBPM: [Double] = []
    private var calResp: [Double] = []
    private var calRate: [Double] = []

    func startCalibration() {
        calibrationStep = 0
        calBPM = []; calResp = []; calRate = []
        calibrationPrompt = calibrationPrompts[0]
        state = .calibrating
    }

    // Player pressed to answer the current calibration prompt.
    func calibrationPressed() {
        responseClockStart = Date()
        try? speech.startListening()
    }

    // Player finished one prompt — capture, then advance or finish + average.
    func calibrationReleased() {
        let responseTime = Date().timeIntervalSince(responseClockStart ?? Date())
        Task {
            state = .loading   // reuse the "reading heart rate" screen + countdown
            let speechResult = await speech.stopAndTranscribe()
            let bpm = await heart.currentBPM()

            calBPM.append(bpm)
            if responseTime > 0 { calResp.append(responseTime) }
            if speechResult.speechRate > 0 { calRate.append(speechResult.speechRate) }

            calibrationStep += 1
            if calibrationStep < calibrationPrompts.count {
                calibrationPrompt = calibrationPrompts[calibrationStep]
                state = .calibrating
            } else {
                // Average the captures; fall back to the old baseline per-signal
                // if every capture for that signal was empty.
                baseline = Baseline(
                    heartRate: average(calBPM) ?? baseline.heartRate,
                    responseTime: average(calResp) ?? baseline.responseTime,
                    speechRate: average(calRate) ?? baseline.speechRate
                )
                isCalibrated = true
                state = .idle
            }
        }
    }

    private func average(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    // --- Push-to-talk ---

    // Asker pressed down — start capturing so we can transcribe the question.
    func askerPressed() {
        try? speech.startListening()
    }

    // Asker let go. Transcribe the spoken question (option A: the LLM needs the
    // question text to judge how evasive the ANSWER is relative to it).
    //
    // Solo (no peers connected): the same device now becomes the answerer, so
    // one phone can play a full ask -> answer -> result round. This is also the
    // single-question path the LLM needs to be testable end-to-end.
    //
    // Multiplayer (peers connected): broadcast the question text to the room so
    // the answerer's phone can feed it to its LLM, then wait for the result.
    // ponytail: the multiplayer broadcast of the question isn't wired yet —
    // needs turn-order sync (see RoomService.swift). Solo path works today.
    func askerReleased() {
        Task {
            let q = await speech.stopAndTranscribe()
            setQuestion(q.text)

            if room.connectedPeers.isEmpty {
                // Solo: this phone answers its own question next.
                myRole = .answerer
                responseClockStart = Date()
                state = .answering
            } else {
                // Multiplayer: TODO broadcast `q.text` to the answerer's phone.
                state = .waitingForResult
            }
        }
    }

    // One entry point for the question text, so the solo path (above) and a
    // future received-over-the-room message both set it the same way.
    func setQuestion(_ text: String) {
        currentQuestion = text
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

    // "Next round" — restart the loop: ask -> answer -> loading -> calculating
    // -> result -> (next) -> ask... The asker's release solo-flips to answering
    // (see askerReleased), so this just drops back to the asking screen.
    func nextRound() {
        startRound()
    }

    // TEMP (testing/debugging only): a fixed single-phone loop that skips the
    // roulette + role assignment so one device can run ask->answer->result
    // repeatedly. RESTORE for real multiplayer: point "Start"/nextRound back at
    // startSession() (roulette role reveal) once the sensor + LLM fixes are done.
    func startRound() {
        lastResult = nil
        currentQuestion = ""
        myRole = .asker
        state = .asking
    }
}
