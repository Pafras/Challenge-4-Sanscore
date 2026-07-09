// AudioManager.swift
// One place for ALL app sound: looping BGM per screen group + one-shot SFX.
// Reads the Settings sliders/toggle straight from UserDefaults (same keys as
// SettingsView's @AppStorage), so volume changes apply live via refreshVolumes().
//
// BGM rule: playBGM(track) does NOTHING if that track is already playing —
// that's how Home keeps playing seamlessly across home -> finding room ->
// enter code (all the same .home track, never restarted).
//
// Mic note: BGM is STOPPED during ask/answer/calibrate (GameFlowView decides)
// so the speech capture doesn't record our own music.
//
// OWNER: Marleen (UI/audio). No game logic here.

import AVFoundation
import Foundation

enum BGMTrack: String {
    case home         = "BGM-Home"            // home + finding room + enter code
    case setupProfile = "BGM-SetupProfile"    // name entry + take a picture
    case gameRoom     = "BGM-GameRoom"        // lobby, host + player
    case beginNext    = "BGM-BeginNext"       // let's begin / who's next / picking roles
    case calcResult   = "BGM-CalculateResult" // calculating + result
}

enum SFX: String {
    case click     = "SFX-ButtonClick"
    case start     = "SFX-ButtonStart"        // START pressed (heard by everyone)
    case camera    = "SFX-Camera"
    case heartbeat = "SFX-HeartBeat"          // looped while a live BPM is on screen
    // Role announce stingers — played when the picked role is revealed.
    case roleInterrogator = "INTERROGATOR"
    case roleSuspect      = "SUSSPECT"
    case roleSpectator    = "SPECTATOR"
    // Result stingers — one per sus band (played when the result screen shows).
    case resultVerySus   = "SUSS1"
    case resultKindaSus  = "SUSS2"
    case resultKindaTruth = "TRUTH2"
    case resultVeryTruth = "TRUTH1"
}

final class AudioManager {
    static let shared = AudioManager()

    private var bgm: AVAudioPlayer?
    private(set) var currentTrack: BGMTrack?
    private var heartbeat: AVAudioPlayer?
    // Keep one-shot players alive until they finish (AVAudioPlayer stops if
    // deallocated); cleaned up lazily on the next play.
    private var oneShots: [AVAudioPlayer] = []

    private init() {
        // .ambient + mixWithOthers: politest category — never fights the mic
        // session the speech capture sets up. (This exact setup is the one that
        // played reliably; do NOT force .playback / setActive here, it broke
        // playback outright.)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        // Self-healing: the mic (speech) and the PPG camera both kill the shared
        // audio session at unpredictable moments (record + setActive(false)),
        // which silently stops whatever BGM was running — that's why calculating
        // died after a brief moment. A 1s watchdog just calls play() again;
        // AVAudioPlayer reactivates the session itself on play.
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.currentTrack != nil, let player = self.bgm else { return }
            // Dead = not playing, OR "zombie": isPlaying still true but the
            // session was killed under it so playback is frozen (currentTime
            // stopped advancing) — that's the calculating "stops halfway" bug.
            let progress = player.currentTime
            let frozen = player.isPlaying && progress == self.lastProgress
            if !player.isPlaying || frozen {
                self.reassertAmbient()
                if frozen { player.pause() }   // reset the zombie state
                player.play()
            }
            self.lastProgress = progress
        }
    }

    private var watchdog: Timer?
    private var lastProgress: TimeInterval = -1

    // The recipe that brought sound back after the mic (confirmed on device):
    // re-assert .ambient AND reactivate. Used by playBGM + the watchdog.
    private func reassertAmbient() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // Volumes live in UserDefaults under the SettingsView keys.
    private var bgmVolume: Float {
        Float(UserDefaults.standard.object(forKey: "settings.bgmVolume") as? Double ?? 0.6)
    }
    private var sfxVolume: Float {
        Float(UserDefaults.standard.object(forKey: "settings.sfxVolume") as? Double ?? 0.7)
    }

    // MARK: BGM

    /// Loop a track. No-op if it's ALREADY the current one AND audible.
    func playBGM(_ track: BGMTrack) {
        if currentTrack == track {
            // Same track but the mic session may have killed it — revive.
            if bgm?.isPlaying != true { reassertAmbient(); bgm?.play() }
            return
        }
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3") else { return }
        reassertAmbient()
        bgm?.stop()
        bgm = try? AVAudioPlayer(contentsOf: url)
        bgm?.numberOfLoops = -1
        bgm?.volume = bgmVolume
        bgm?.play()
        currentTrack = track
        // (Late session teardown from the mic/camera is handled by the watchdog.)
    }

    func stopBGM() {
        bgm?.stop()
        bgm = nil
        currentTrack = nil
    }

    // MARK: SFX

    func playSFX(_ sfx: SFX) {
        guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "mp3") else { return }
        oneShots.removeAll { !$0.isPlaying }          // drop finished players
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = sfxVolume
        player.play()
        oneShots.append(player)
    }

    /// Looping heartbeat while a live BPM readout is on screen.
    func startHeartbeat() {
        guard heartbeat?.isPlaying != true else { return }
        guard let url = Bundle.main.url(forResource: SFX.heartbeat.rawValue, withExtension: "mp3") else { return }
        heartbeat = try? AVAudioPlayer(contentsOf: url)
        heartbeat?.numberOfLoops = -1
        heartbeat?.volume = sfxVolume
        heartbeat?.play()
    }

    func stopHeartbeat() {
        heartbeat?.stop()
        heartbeat = nil
    }

    /// Call when the Settings sliders move — applies to whatever is playing.
    func refreshVolumes() {
        bgm?.volume = bgmVolume
        heartbeat?.volume = sfxVolume
    }
}
