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
    private(set) var resultBPM: Int?   // answerer's recorded BPM for the shown result
    private(set) var resultTranscript: String?   // what the answerer said (closed captions, final)
    private(set) var liveCaption: String?        // live transcript during the answer (closed captions)

    // The caption text to show for the current screen (nil = nothing). Live
    // transcript while the answer is happening (suspect/spectator/asker all see
    // it), then the final transcript on the result screen. ClosedCaptionView
    // gates it on the iOS Closed Captions setting.
    var captionText: String? {
        switch state {
        case .answering, .fingerCheck, .spectating, .waitingForResult: return liveCaption
        case .result: return resultTranscript
        default: return nil
        }
    }
    // Shown on the start screen when a room ends unexpectedly (host left, etc.).
    var roomAlert: String?
    // Transient toast over gameplay, e.g. "Budi left". Auto-clears.
    // Carries a semantic style (neutral/warning/danger/success) for the UI.
    var toast: Toast?
    // Track whether we ever fully connected, to tell "never joined" from "peer left".
    private var everConnected = false
    // Who's the asker/answerer this round — so we know if a leaver breaks it.
    private var currentAsker = ""
    private var currentAnswerer = ""

    // Lobby avatars: player name -> tiny JPEG. Includes self. UI shows these as
    // floating bubbles; falls back to initials when a player has no photo.
    var avatars: [String: Data] = [:]
    // ponytail: the asker only speaks the question out loud (push-to-talk,
    // no typing) — nothing captures its text yet, so this stays "". Fine for
    // Mock testing since StructureAnalyzing doesn't need it; the real LLM
    // (StructureAnalyzer) will need the asker's question transcribed too.
    var currentQuestion: String = ""

    // --- Real room networking (create/join + result broadcast). ---
    // Recreated when the player picks a name (MCPeerID's name is fixed at init).
    private(set) var room: RoomService

    // The human LABEL shown on this player's bubble. Random party name by default
    // (iOS 16+ redacts UIDevice.name to a generic "iPhone", so a random pick both
    // avoids that AND stops the real device name leaking to strangers on the
    // network); players can rename in the lobby. Display-only — the network
    // IDENTITY is `installID`.
    var playerName: String = GameViewModel.randomPlayerName()

    // ponytail: small curated pool, one random pick. Grow the list if names repeat.
    static let playerNamePool = ["Sneaky Fox", "Sus Otter", "Shady Cat", "Sly Duck",
                                 "Cool Bean", "Lie Llama", "Truth Toad", "Fibby Frog",
                                 "Bluff Bear", "Honest Owl", "Cheeky Crab", "Dodgy Deer"]
    static func randomPlayerName() -> String { playerNamePool.randomElement()! }

    // Stable, unique-per-install id used as the MCPeerID NAME (the key for
    // avatars/turns/players). Must be unique per device, but iOS 16+ makes
    // UIDevice.name "iPhone" for EVERYONE, so two phones would collide (same
    // key -> one player's photo overwrites the other's). A random id kept in
    // UserDefaults stays stable across launches and distinct across devices.
    // ponytail: 6 hex chars = plenty for a 4-5 person party room.
    static var installID: String {
        let key = "sanscore.installID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6))
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

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

    // Inject anything conforming to the protocols. Real modules need a real
    // iPhone (camera/mic) and, for the LLM, iOS 26 + Apple Intelligence, so on
    // the Simulator / older OS we auto-fall back to mocks — lets 2-Simulator
    // multiplayer testing build + run without hardware. Pass explicit modules
    // to override.
    init(engine: SusEngine = SusEngine(),
         heart: HeartRateSource? = nil,
         speech: SpeechCapturing? = nil,
         structure: StructureAnalyzing? = nil) {
        self.engine = engine
        #if targetEnvironment(simulator)
        self.heart = heart ?? MockHeartRate()
        self.speech = speech ?? MockSpeech()
        self.structure = structure ?? MockStructure()
        #else
        self.heart = heart ?? RealHeartRate()
        self.speech = speech ?? RealSpeechCapture()
        // Real LLM only where Foundation Models exists + iOS 26; else mock.
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            self.structure = structure ?? StructureAnalyzer()
        } else {
            self.structure = structure ?? MockStructure()
        }
        #else
        self.structure = structure ?? MockStructure()
        #endif
        #endif
        // Identity = device name + unique install id, so two "iPhone"s never
        // collide. The clean label is broadcast separately via `displayNames`.
        self.room = RoomService(displayName: "\(UIDevice.current.name)-\(Self.installID)")
        wireRoom()
        // Seed my display label so my bubble shows the clean name, not the
        // suffixed identity key.
        displayNames[myName] = playerName
    }

    private func wireRoom() {
        room.onMessage = { [weak self] message in self?.handle(message) }
        room.onConnectionChange = { [weak self] in self?.connectionChanged() }
        room.onPeerLeft = { [weak self] name in self?.peerLeft(name) }
    }

    // Chosen display names by stable id (MCPeerID name). The network identity
    // never changes; only the shown label does — so a player can rename any time
    // (even mid-lobby) without dropping the connection.
    var displayNames: [String: String] = [:]

    // The label to show for a player (their chosen name, else their peer name).
    func label(for name: String) -> String { displayNames[name] ?? name }

    // Set/change my display name — broadcast it; no reconnect. If I'm the host,
    // also re-advertise so the nearby-room list shows the new name.
    func setDisplayName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        playerName = trimmed
        displayNames[myName] = trimmed
        room.send(.rename(id: myName, display: trimmed))
        room.updateHostName(trimmed)
        if room.isHost { room.send(.roomInfo(title: trimmed)) }   // update lobby title
    }

    private var inRound: Bool { state != .idle && state != .identity && state != .roomLobby }

    // A peer joined or left — track connection for the "host left" check.
    private func connectionChanged() {
        if !room.connectedPeers.isEmpty {
            everConnected = true
            // NOTE: a joiner does NOT advance here — connecting isn't enough, the
            // host must confirm the code (joinAccepted, handled in handle()). We
            // accept-then-validate so a wrong code gets an instant reply.
            // A newcomer won't have our avatar/name yet — resend both.
            if let mine = avatars[myName] { room.send(.profile(name: myName, image: mine, colorIndex: avatarColorIndex[myName] ?? 0)) }
            if let name = displayNames[myName] { room.send(.rename(id: myName, display: name)) }
            if lobbyMembers.contains(myName) { room.send(.inLobby(name: myName)) }
            // Host tells joiners the room title (its own name) for the lobby header.
            if room.isHost { room.send(.roomInfo(title: playerName)) }
        }
    }

    // Player took/retook their lobby photo. Downscale to a tiny JPEG (the local
    // network can't carry full-size images), store, and broadcast to the room.
    // Chosen background colour index per player (drives the lobby name badge).
    var avatarColorIndex: [String: Int] = [:]

    // Who has FINISHED profile setup (name + photo) and entered the lobby.
    // A peer connects the moment their code is accepted — while they're still
    // typing their name — so the lobby only shows players in this set, not
    // everyone connected. Announced via .inLobby (see enterLobby).
    var lobbyMembers: Set<String> = []
    var lobbyPlayers: [String] { room.players.filter { lobbyMembers.contains($0) } }

    func setMyAvatar(_ image: UIImage, colorIndex: Int = 0) {
        guard let data = image.jpegThumbnail(maxSide: 160, quality: 0.6) else { return }
        avatars[myName] = data
        avatarColorIndex[myName] = colorIndex
        room.send(.profile(name: myName, image: data, colorIndex: colorIndex))
    }

    // A specific peer left. Decide based on who they were:
    // - host left     -> room closes, everyone to start screen.
    // - active asker/answerer left -> this round can't finish -> back to lobby.
    // - anyone else (spectator/lobby) -> keep going, just a toast.
    private func peerLeft(_ name: String) {
        lobbyMembers.remove(name)
        // If we're waiting at the reveal barrier, stop waiting on the leaver —
        // otherwise the host hangs until the 25s timeout.
        if state == .syncing {
            revealParticipants.remove(name)
            readyPlayers.remove(name)
            checkRevealBarrier()
        }
        // On the result screen, a leaver shrinks the ready target — re-check so
        // the remaining players' READYs can still start the next round.
        if state == .result {
            nextReady.remove(name)
            checkNextBarrier()
        }
        // Ignore drops fired by our own leave — we're already heading to start.
        guard state != .idle else { return }
        // Host left: as a joiner, we lose all peers.
        if !room.isHost, everConnected, room.connectedPeers.isEmpty {
            endRoom("The room closed — the host left.")
            return
        }
        let shown = label(for: name)
        if inRound, name == currentAsker || name == currentAnswerer {
            returnToLobby("\(shown) left — round ended.")
        } else {
            showLeftNotice("\(shown) left the room")
        }
    }

    // Transient toast that clears itself.
    private var noticeToken = 0
    private func showLeftNotice(_ text: String, style: ToastStyle = .neutral) {
        toast = Toast(message: text, style: style)
        noticeToken += 1
        let token = noticeToken
        Task {
            try? await Task.sleep(for: .seconds(3))
            if token == noticeToken { toast = nil }
        }
    }

    // Manual dismiss (tap the X on the toast).
    func dismissToast() {
        noticeToken += 1   // cancel the pending auto-clear
        toast = nil
    }

    // Manual dismiss for the persistent room alert (host left / you left).
    func dismissRoomAlert() { roomAlert = nil }
    
    // User tapped Leave in the lobby — disconnect, back to start with a note on
    // THIS device ("You left"); the others get an "X left" toast via peerLeft.
    func leaveRoom() {
        endRoom("You left the room.")   // endRoom now tears down the network too
    }

    // Full teardown to the start screen (host left, or user tapped Back).
    // Must stop the network too — otherwise a host returning home keeps
    // advertising and shows up as a ghost room in everyone's join list.
    func endRoom(_ reason: String?) {
        room.leave()
        roomAlert = reason
        toast = nil             // don't carry a stray "X left" toast to the start screen
        everConnected = false
        lobbyMembers = []
        round = 0
        hasPlayedARound = false   // next session's first reveal = LET'S BEGIN again
        waitToken += 1          // cancel any pending round timeout
        state = .idle
        // Auto-dismiss the home-screen notice after 3s so it doesn't linger.
        if let shown = reason {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.roomAlert == shown { self?.roomAlert = nil }
            }
        }
    }

    // Soft reset: keep the room + connection, drop back to the lobby.
    private func returnToLobby(_ reason: String?) {
        roomAlert = reason
        waitToken += 1          // cancel any pending round timeout
        state = .roomLobby
    }

    // Spectator taps Back — drop to the waiting room (stay in the room), not
    // all the way out to the home screen.
    func spectatorToLobby() {
        returnToLobby(nil)
    }

    var myName: String { room.myPeerID.displayName }
    private var round = 0   // host-only round counter for round-robin turns

    // Every message from another phone lands here.
    private func handle(_ message: RoomMessage) {
        switch message {
        case let .turn(asker, answerer):
            // Still mid-setup (name/photo)? Not in this round — sit it out in
            // peace; we join the lobby when done and play the next one.
            guard lobbyMembers.contains(myName) else { return }
            applyTurn(asker: asker, answerer: answerer)
        case let .question(text):
            // Only the answerer needs the question (for the LLM).
            if myRole == .answerer { setQuestion(text) }
        case let .result(result):
            // Asker (waiting) + spectators show it; the answerer already has it.
            guard state == .waitingForResult || state == .spectating else { return }
            lastResult = SusResult(score: result.score, band: SusBand(score: result.score), verdict: result.verdict)
            resultBPM = result.bpm
            resultTranscript = result.transcript
            hasPlayedARound = true
            state = .result
        case let .profile(name, image, colorIndex):
            avatars[name] = image
            avatarColorIndex[name] = colorIndex
        case let .rename(id, display):
            displayNames[id] = display
        case let .inLobby(name):
            lobbyMembers.insert(name)
        case let .ready(name):
            // Host tallies readiness; fires the reveal once everyone's in.
            guard room.isHost else { return }
            readyPlayers.insert(name)
            checkRevealBarrier()
        case .beginReveal:
            // Host says go — every device starts the reveal on THIS message.
            guard state == .syncing else { return }
            revealToken &+= 1          // cancel our backstop timeout
            runRoleSequence()
        case let .readyNext(name):
            // Everyone tallies (so every result screen shows the live x/y); only
            // the host acts on all-ready.
            nextReady.insert(name)
            checkNextBarrier()
        case let .caption(text):
            // Live closed captions of the answer, for the asker + spectators.
            guard state == .waitingForResult || state == .spectating else { return }
            liveCaption = text
        case .joinAccepted:
            // Host confirmed the code -> we're in. Name screen, then photo.
            if pendingJoin {
                pendingJoin = false
                joinToken &+= 1        // cancel the safety timeout
                joinError = nil
                room.stopBrowsing()
                state = .nameEntry
            }
        case .joinRejected:
            // Host says the code was wrong -> instant warning, leave the session,
            // stay on the code screen (room still listed) to retype.
            if pendingJoin {
                pendingJoin = false
                joinToken &+= 1
                joinError = "Wrong code. Please enter the right code."
                room.disconnectSession()
            }
        case let .roomInfo(title):
            if !room.isHost { roomTitle = title }   // joiner shows the host's room title
        }
    }

    // This device's role for the round, from the host's assignment. Figma
    // order: calibrate first (once per session, all devices in parallel),
    // then the LET'S BEGIN / picking-roles sequence.
    private func applyTurn(asker: String, answerer: String) {
        lastResult = nil
        resultBPM = nil
        resultTranscript = nil
        liveCaption = nil
        nextReady.removeAll()          // fresh ready-up for the new round
        currentQuestion = ""
        currentAsker = asker
        currentAnswerer = answerer
        // Decide THIS device's role NOW so the reveal screen can show the right
        // one (Interrogator = asker, Suspect = answerer, Spectator = the rest).
        if myName == asker { myRole = .asker }
        else if myName == answerer { myRole = .answerer }
        else { myRole = .spectator }

        // First round of a session: calibrate this player, THEN report ready and
        // wait at the barrier so every device starts the reveal on the same beat
        // (calibration takes different real time per phone). Later rounds skip
        // straight to the barrier (resolves instantly — nobody calibrates).
        if !isCalibrated {
            afterCalibration = { [weak self] in self?.reportReady() }
            startCalibration()
        } else {
            reportReady()
        }
    }

    // --- Reveal barrier (keeps every device's calibrate -> reveal in step) ---
    // Each device calibrates at its own pace; without a barrier the LET'S BEGIN
    // / picking-roles / role screens land at visibly different times. So every
    // device announces .ready when done, the host waits for all of them, then
    // broadcasts .beginReveal — everyone starts the reveal on the same message.
    private var readyPlayers: Set<String> = []      // host: who has reported ready
    private var revealParticipants: Set<String> = []// host: who this round waits on
    private var revealToken = 0                      // cancels a stale barrier timeout

    private func reportReady() {
        // Solo (no peers): no one to sync with — go straight to the reveal.
        guard !room.connectedPeers.isEmpty else { runRoleSequence(); return }
        state = .syncing
        // Backstop either way: a crashed/slow device must not hang the reveal.
        armRevealTimeout()
        if room.isHost {
            readyPlayers.insert(myName)
            checkRevealBarrier()
        } else {
            room.send(.ready(name: myName))
        }
    }

    // Host: all expected players ready -> fire the reveal for everyone at once.
    private func checkRevealBarrier() {
        guard room.isHost, revealParticipants.isSubset(of: readyPlayers) else { return }
        revealToken &+= 1               // cancel the pending timeout
        room.send(.beginReveal)
        runRoleSequence()
    }

    // If a device crashed / never reports, don't wait on it forever.
    private func armRevealTimeout() {
        revealToken &+= 1
        let token = revealToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            guard let self, self.revealToken == token, self.state == .syncing else { return }
            if self.room.isHost { self.room.send(.beginReveal) }
            self.runRoleSequence()
        }
    }

    // Roulette ("picking roles"), then land on the assigned screen.
    private func runRoleSequence() {
        state = .roleReveal
        Task {
            // 1.3s LET'S BEGIN / WHO'S NEXT card (RoleRevealIntro) + ~3.2s of
            // "picking roles" bubbles breathing.
            try? await Task.sleep(for: .seconds(4.5))
            // Spectator: go straight to .spectating, which shows the "you're the
            // spectator" screen and KEEPS it on (no separate roleResult, so its
            // reveal animation plays once and stays).
            if myRole == .spectator {
                state = .spectating
                armResultTimeout()
                return
            }
            state = .roleResult                        // Interrogator/Suspect reveal
            try? await Task.sleep(for: .seconds(2))    // reveal animation plays
            switch myRole {
            case .asker:
                state = .asking
            case .answerer:
                await beginAnswering()
            case .spectator:
                break   // handled above
            }
        }
    }

    // Suspect's path into answering (Figma): the "put finger on camera"
    // warning first, then live HR capture runs THROUGH the answer, feeding
    // the rolling BPM readout — HR is measured during the stress, not after.
    private(set) var liveBPM: Int?

    // True once any round in this session finished. Drives the roleReveal
    // intro card: first round = LET'S BEGIN, after = WHO'S NEXT. (Can't use
    // lastResult — applyTurn nils it before the reveal shows.)
    private(set) var hasPlayedARound = false

    private func beginAnswering() async {
        state = .fingerCheck
        try? await Task.sleep(for: .seconds(3.5))   // read the warning, finger on
        // WarningView's own camera preview tears down when the state flips;
        // give AVFoundation a beat before grabbing the camera for PPG.
        // ponytail: fixed waits, no finger detection. Detect via frame redness
        // if players keep missing the lens.
        state = .answering
        responseClockStart = Date()
        liveCaption = nil
        try? await Task.sleep(for: .seconds(0.5))
        await heart.startLiveCapture()
        // Poll the rolling BPM + live transcript into the UI until the answer is
        // scored, and broadcast the transcript so the asker + spectators see the
        // same live closed captions.
        Task { [weak self] in
            while let self, self.state == .answering || self.state == .fingerCheck {
                self.liveBPM = self.heart.liveBPM().map { Int($0.rounded()) }
                let caption = self.speech.liveTranscript
                if caption != self.liveCaption {
                    self.liveCaption = caption
                    if let caption, !caption.isEmpty { self.room.send(.caption(caption)) }
                }
                try? await Task.sleep(for: .seconds(1))
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

    // The lobby header title — the host's chosen name ("ROOM AGUNG"). Host uses
    // its own playerName; a joiner gets it broadcast via .roomInfo. The room is
    // also advertised under this name (see enterLobby) so the finding-room list
    // matches.
    var roomTitle: String = ""

    // Set when the player tapped CREATE: they become host only once they finish
    // the identity screen and enter the lobby (so the photo screen doesn't
    // advertise a ghost room to everyone).
    private var pendingHostRoom = false
    // Set while a join invite is in flight: advance to identity only when the
    // host accepts (correct code) and we actually connect.
    private var pendingJoin = false
    // Shown on the code-entry card when a code fails. UI watches this.
    var joinError: String?
    private var joinToken = 0

    func createRoom() {
        roomAlert = nil
        displayNames[myName] = playerName
        // Flow: name -> photo -> lobby. Don't start hosting yet — advertise only
        // when they actually enter the lobby.
        pendingHostRoom = true
        state = .nameEntry
    }

    // Name-entry DONE -> save the display name, go to the photo screen.
    func finishNameEntry(_ name: String) {
        setDisplayName(name)
        state = .identity
    }

    // "Join room" — start scanning for nearby hosts (shown in a picker).
    func startBrowsing() {
        roomAlert = nil
        displayNames[myName] = playerName
        room.startBrowsing()
    }

    // Joiner picked a nearby room + typed the code -> invite, go wait in lobby.
    // If the code is wrong the host rejects and the lobby stays empty.
    func join(_ host: MCPeerID, code: String) {
        // Invite with the code but DON'T advance yet — the host accepts only if
        // the code matches its generated one. We move to identity only once
        // actually connected (see connectionChanged). Keep browsing so the room
        // stays listed.
        joinError = nil
        pendingJoin = true
        joinToken &+= 1
        let token = joinToken
        room.join(host, code: code)
        // Safety net ONLY: the host replies joinAccepted/joinRejected the instant
        // we connect (handled in handle()), so a wrong code warns immediately.
        // This fires just if neither reply arrives — host vanished / bad network.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.pendingJoin, self.joinToken == token else { return }
            self.pendingJoin = false
            self.joinError = "Couldn't reach the room. Try again."
        }
    }

    // JOIN on the identity screen -> actually enter the lobby. If they tapped
    // CREATE, THIS is when the room opens (advertising starts) — not before.
    // Photo was already captured + broadcast via setMyAvatar.
    func enterLobby() {
        if pendingHostRoom {
            // Advertise the room under the HOST'S NAME (e.g. "AGUNG"), so the
            // finding-room list matches the lobby header "ROOM AGUNG".
            room.startHosting(name: playerName)
            pendingHostRoom = false
        }
        // Setup done — reveal my bubble on everyone's lobby (see lobbyMembers).
        lobbyMembers.insert(myName)
        room.send(.inLobby(name: myName))
        state = .roomLobby
    }

    // Back button on the identity screen -> abandon the create/join and return
    // home. Never advertised (host only opens on enterLobby), but still leave to
    // drop any join connection. No "you left" alert — never entered the lobby.
    func cancelIdentity() {
        pendingHostRoom = false
        room.leave()
        everConnected = false
        lobbyMembers = []
        state = .idle
    }

    // Host taps "Start"/"Next round": pick this round's asker + answerer
    // round-robin from the player list, broadcast to everyone, and apply it
    // locally (the host plays too). Only the host calls this.
    func startSession() {
        roomAlert = nil
        // Only players who finished setup — someone mid-photo can't take a turn.
        let players = lobbyPlayers
        guard players.count >= 2 else { return }   // need at least an asker + answerer
        let asker = players[round % players.count]
        let answerer = players[(round + 1) % players.count]
        round += 1
        // Arm the reveal barrier for exactly these players before anyone starts.
        revealParticipants = Set(players)
        readyPlayers = []
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

    // --- Calibration (Figma) ---
    // One quick sequence, no prompts: LETS CALIBRATE instruction -> put-finger
    // warning -> MEASURING HEART RATE ("I swear that I'm telling the truth",
    // live BPM). Captures the player's resting HR as the baseline.
    // ponytail: only the HR baseline is measured now; responseTime/speechRate
    // baselines stay at their defaults. Bring back spoken calibration prompts
    // if those two signals score poorly.
    var isCalibrated = false
    // What to do once calibration finishes (continue into the round). nil =
    // stand-alone calibration, fall back to the start screen.
    private var afterCalibration: (() -> Void)?

    enum CalibrationPhase { case instruction, warning, measuring }
    private(set) var calibrationPhase: CalibrationPhase = .instruction

    func startCalibration() {
        calibrationPhase = .instruction
        state = .calibrating
        // Instruction screen waits for a TAP (advanceFromInstruction) instead
        // of auto-advancing, so the player reads it at their own pace.
    }

    // Tapped "tap anywhere to continue" on LETS CALIBRATE → run the rest of the
    // sequence: put-finger warning -> MEASURING HEART RATE (live BPM) -> baseline.
    func advanceFromInstruction() {
        guard state == .calibrating, calibrationPhase == .instruction else { return }
        Task {
            calibrationPhase = .warning                 // put finger on camera
            try? await Task.sleep(for: .seconds(3.5))
            calibrationPhase = .measuring               // "I swear..." + live BPM
            // WarningView's own camera tears down on the phase flip; give
            // AVFoundation a beat before grabbing the camera for PPG.
            try? await Task.sleep(for: .seconds(0.5))
            await heart.startLiveCapture()
            let poll = Task { [weak self] in
                while let self, self.state == .calibrating {
                    self.liveBPM = self.heart.liveBPM().map { Int($0.rounded()) }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            try? await Task.sleep(for: .seconds(8))     // PPG sample window
            let bpm = await heart.finishLiveCapture()
            poll.cancel()
            // Hold the final reading on screen for a beat, then move on to
            // LET'S BEGIN -> picking roles (RoleRevealIntro handles the card).
            liveBPM = Int(bpm.rounded())
            try? await Task.sleep(for: .seconds(1.5))
            liveBPM = nil

            baseline.heartRate = bpm
            isCalibrated = true
            // Mid-flow (Figma: calibrate right after the host starts):
            // continue into the round. Stand-alone: back to the start.
            if let next = afterCalibration {
                afterCalibration = nil
                next()
            } else {
                state = .idle
            }
        }
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
                // Solo: this phone answers its own question next — same
                // finger-warning + live-HR path as multiplayer.
                myRole = .answerer
                await beginAnswering()
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
        // Straight to the animated sus-meter (CalculatingView) — no separate
        // loading screen. HR was captured LIVE during the answer, so there's
        // no finger-on-camera countdown to wait on anymore. The meter needle
        // sweeps (targetScore == nil) while transcribe + LLM run below, then
        // eases to the real score once lastResult is set.
        state = .calculating
        let speechResult = await speech.stopAndTranscribe()
        // HR was captured live DURING the answer (started in beginAnswering);
        // this just stops the camera and reads the estimate — near instant.
        let bpm = await heart.finishLiveCapture()
        liveBPM = nil
        let recordedBPM = Int(bpm.rounded())   // shown on the result screen + broadcast
        resultBPM = recordedBPM
        let transcript = speechResult.text.isEmpty ? nil : speechResult.text   // closed captions
        resultTranscript = transcript

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
        hasPlayedARound = true

        // Score is known now, but hold on the .calculating screen a beat so its
        // meter needle can animate to the real score before we reveal .result.
        // CalculatingView reads lastResult?.score to know where to land.
        try? await Task.sleep(for: .seconds(2.6))

        state = .result

        room.send(.result(RoundResult(answererName: myName, score: result.score, verdict: result.verdict, bpm: recordedBPM, transcript: transcript)))
    }

    // Only the host (or a solo device) drives the pace. Non-host clients wait
    // --- Result-screen ready-up (every player, incl. host, taps READY) ---
    // Each device tallies who has tapped; the host starts the next round once
    // all lobby players are in. Reset per round in applyTurn.
    private(set) var nextReady: Set<String> = []
    var readyForNextCount: Int { nextReady.count }
    var totalForNext: Int { max(1, lobbyPlayers.count) }
    var iAmReadyForNext: Bool { nextReady.contains(myName) }

    // This device tapped READY on the result screen.
    func markReadyForNext() {
        if room.connectedPeers.isEmpty { nextRound(); return }   // solo: no barrier
        guard !nextReady.contains(myName) else { return }        // one tap only
        nextReady.insert(myName)
        room.send(.readyNext(name: myName))
        checkNextBarrier()
    }

    // Host: once every player on the result screen has readied, start next round.
    // (applyTurn clears nextReady for the new round.)
    private func checkNextBarrier() {
        guard room.isHost, state == .result else { return }
        guard nextReady.isSuperset(of: lobbyPlayers) else { return }
        startSession()
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

    // Solo single-phone loop: this device asks then answers. Same visual
    // sequence as multiplayer (calibrate -> LET'S BEGIN -> picking roles ->
    // reveal), just without the host's turn broadcast.
    func startRound() {
        roomAlert = nil
        lastResult = nil
        currentQuestion = ""
        myRole = .asker
        if !isCalibrated {
            afterCalibration = { [weak self] in self?.runRoleSequence() }
            startCalibration()
        } else {
            runRoleSequence()
        }
    }
}
