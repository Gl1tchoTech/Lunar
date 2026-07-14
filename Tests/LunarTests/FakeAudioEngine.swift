import Foundation

/// In-memory audio engine fake. Used by unit tests so we never have
/// to instantiate the real `AVAudioEngine` (which requires audio
/// hardware unavailable to CI / simulators without sound cards).
///
/// Sets `state` directly so tests can drive it without timers, and
/// records every `send(_:)` for sequential assertions.
@MainActor
@Observable
final class FakeAudioEngine: AudioPlayerInterface {

    private(set) var state = PlayerState()

    /// Complete ordered log of every command sent.
    private(set) var sentCommands: [PlaybackCommand] = []

    /// Optional fake-load helper: when a `.load` or `.crossfade`
    /// arrives, simulate by setting state as if the song finished
    /// loading. Default off so tests can opt-in via `autoLoad`.
    var autoLoad: Bool = true
    var loadDurationSeconds: TimeInterval = 180

    func send(_ command: PlaybackCommand) async {
        sentCommands.append(command)

        guard autoLoad else { return }

        switch command {
        case .load(let req):
            state.currentTitle = req.title
            state.currentArtist = req.artist
            state.duration = req.duration > 0 ? req.duration : loadDurationSeconds
            state.currentTime = 0
        case .crossfade(let req, _):
            state.currentTitle = req.title
            state.currentArtist = req.artist
            state.duration = req.duration > 0 ? req.duration : loadDurationSeconds
            state.currentTime = 0
            state.isPlaying = true
        case .play:
            state.isPlaying = true
        case .pause:
            state.isPlaying = false
        case .togglePlayPause:
            state.isPlaying.toggle()
        case .seek(let t):
            state.currentTime = t
        case .setVolume(let v):
            state.volume = v
        case .setEQ:
            break
        case .next, .previous:
            break
        }
    }

    /// Test helper to advance the simulated clock without timers.
    func tickProgress(by seconds: TimeInterval) {
        guard state.isPlaying else { return }
        state.currentTime = min(state.currentTime + seconds, state.duration)
        if state.currentTime >= state.duration {
            state.isPlaying = false
        }
    }
}
