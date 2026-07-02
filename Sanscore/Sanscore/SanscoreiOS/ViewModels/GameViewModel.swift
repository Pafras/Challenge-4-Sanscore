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
    // Shown on the start screen when a room ends unexpectedly (host left, etc.).
    var roomAlert: String?
    // Transient toast over gameplay, e.g. "Budi left". Auto-clears.
    var leftNotice: String?
    // Track whether we ever fully connected, to tell "never joined" from "peer left".
    private var everConnected = false
    // Who's the asker/answerer this round — so we know if a leaver breaks it.
    private var currentAsker = ""
    private var currentAnswerer = ""
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

    // Inject anything conforming to the protocols. Real speech + heart need a
    // real iPhone (camera/mic), so on the Simulator we auto-fall back to mocks
    // — lets 2-Simulator multiplayer testing build + run without hardware.
    // Pass explicit modules to override. structure/LLM stays mock until Agung's
    // StructureAnalyzer is merged, then swap the default here.
    init(engine: SusEngine = SusEngine(),
         heart: HeartRateSource? = nil,
         speech: SpeechCapturing? = nil,
         structure: StructureAnalyzing = MockStructure()) {
        self.engine = engine
        #if targetEnvironment(simulator)
        self.heart = heart ?? MockHeartRate()
        self.speech = speech ?? MockSpeech()
        #else
        self.heart = heart ?? RealHeartRate()
        self.speech = speech ?? RealSpeechCapture()
        #endif
        self.structure = structure
        self.room = RoomService(displayName: UIDevice.current.name)
        self.room.onMessage = { [weak self] message in self?.handle(message) }
        self.room.onConnectionChange = { [weak self] in self?.connectionChanged() }
        self.room.onPeerLeft = { [weak self] name in self?.peerLeft(name) }
    }

    private var inRound: Bool { state != .idle && state != .roomLobby }

    // A peer joined or left — track connection for the "host left" check.
    private func connectionChanged() {
        if !room.connectedPeers.isEmpty { everConnected = true }
    }

    // A specific peer left. Decide based on who they were:
    // - host left     -> room closes, everyone to start screen.
    // - active asker/answerer left -> this round can't finish -> back to lobby.
    // - anyone else (spectator/lobby) -> keep going, just a toast.
    private func peerLeft(_ name: String) {
        // Host left: as a joiner, we lose all peers.
        if !room.isHost, everConnected, room.connectedPeers.isEmpty {
            if state != .idle { endRoom("The room closed — the host left.") }
            return
        }
        if inRound, name == currentAsker || name == currentAnswerer {
            returnToLobby("\(name) left — round ended.")
        } else {
            showLeftNotice("\(name) left the room")
        }
    }

    // Transient toast that clears itself.
    private var noticeToken = 0
    private func showLeftNotice(_ text: String) {
        leftNotice = text
        noticeToken += 1
        let token = noticeToken
        Task {
            try? await Task.sleep(for: .seconds(3))
            if token == noticeToken { leftNotice = nil }
        }
    }

    // Full teardown to the start screen (host left, or user tapped Back).
    func endRoom(_ reason: String?) {
        roomAlert = reason
        everConnected = false
        round = 0
        waitToken += 1          // cancel any pending round timeout
        state = .idle
    }

    // Soft reset: keep the room + connection, drop back to the lobby.
    private func returnToLobby(_ reason: String?) {
        roomAlert = reason
        waitToken += 1          // cancel any pending round timeout
        state = .roomLobby
    }

    private var myName: String { room.myPeerID.displayName }
    private var round = 0   // host-only round counter for round-robin turns

    // Every message from another phone lands here.
    private func handle(_ message: RoomMessage) {
        switch message {
        case let .turn(asker, answerer):
            applyTurn(asker: asker, answerer: answerer)
        case let .question(text):
            // Only the answerer needs the question (for the LLM).
            if myRole == .answerer { setQuestion(text) }
        case let .result(result):
            // Asker (waiting) + spectators show it; the answerer already has it.
            guard state == .waitingForResult || state == .spectating else { return }
            lastResult = SusResult(score: result.score, band: SusBand(score: result.score), verdict: result.verdict)
            state = .result
        }
    }

    // This device's role for the round, from the host's assignment. Roulette
    // first, then land on the assigned screen.
    private func applyTurn(asker: String, answerer: String) {
        lastResult = nil
        currentQuestion = ""
        currentAsker = asker
        currentAnswerer = answerer
        state = .roleReveal
        Task {
            try? await Task.sleep(for: .seconds(2))
            if myName == asker {
                myRole = .asker
                state = .asking
            } else if myName == answerer {
                myRole = .answerer
                responseClockStart = Date()
                state = .answering
            } else {
                myRole = .spectator
                state = .spectating
                armResultTimeout()
            }
        }
    }

    // Backstop only: real disconnects are caught instantly in connectionChanged.
    // This just catches a silent stall (answerer's app froze but stayed
    // connected). Token guards stale timers from earlier rounds.
    private var waitToken = 0
    private func armResultTimeout(seconds: Double = 30) {
        waitToken += 1
        let token = waitToken
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if token == waitToken, state == .waitingForResult || state == .spectating {
                returnToLobby("No result came back — back to the lobby.")
            }
        }
    }

    // --- Room setup ---

    // "Create room" — become host, generate a code, go to the lobby.
    func createRoom() {
        roomAlert = nil
        room.startHosting()
        state = .roomLobby
    }

    // "Join room" — start scanning for nearby hosts (shown in a picker).
    func startBrowsing() {
        roomAlert = nil
        room.startBrowsing()
    }

    // Joiner picked a nearby room + typed the code -> invite, go wait in lobby.
    // If the code is wrong the host rejects and the lobby stays empty.
    func join(_ host: MCPeerID, code: String) {
        room.join(host, code: code)
        room.stopBrowsing()
        state = .roomLobby
    }

    // Host taps "Start"/"Next round": pick this round's asker + answerer
    // round-robin from the player list, broadcast to everyone, and apply it
    // locally (the host plays too). Only the host calls this.
    func startSession() {
        roomAlert = nil
        let players = room.players
        guard players.count >= 2 else { return }   // need at least an asker + answerer
        let asker = players[round % players.count]
        let answerer = players[(round + 1) % players.count]
        round += 1
        room.send(.turn(asker: asker, answerer: answerer))
        applyTurn(asker: asker, answerer: answerer)
    }

    #if DEBUG
    // Dev-only: force this device's role for solo screen testing (no room).
    func forceRole(_ role: PlayerRole) {
        applyTurn(asker: role == .asker ? myName : "_",
                  answerer: role == .answerer ? myName : "_")
    }
    #endif

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
    // Multiplayer (peers connected): send the question text to the answerer's
    // phone (for its LLM), then wait for the result.
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
                room.send(.question(q.text))
                state = .waitingForResult
                armResultTimeout()
            }
        }
    }

    // One entry point for the question text, so the solo path (above) and a
    // future received-over-the-room message both set it the same way.
    func setQuestion(_ text: String) {
        currentQuestion = text
    }

    // Escape hatch from a waiting/spectating screen back to the start.
    func backToStart() {
        endRoom(nil)
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

        room.send(.result(RoundResult(answererName: myName, score: result.score, verdict: result.verdict)))
    }

    // "Next round". Multiplayer: the host assigns the next turn (round-robin)
    // and broadcasts it. Solo (no peers): fall back to the single-phone loop.
    func nextRound() {
        if room.connectedPeers.isEmpty {
            startRound()
        } else if room.isHost {
            startSession()
        }
        // Non-host multiplayer clients wait for the host's next .turn message.
    }

    // Lobby "Start". Same split as nextRound.
    func start() {
        nextRound()
    }

    // Solo single-phone loop: skip roles, this device asks then answers.
    func startRound() {
        roomAlert = nil
        lastResult = nil
        currentQuestion = ""
        myRole = .asker
        state = .asking
    }
}
