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

    /// Fake queue state so the existing AudioEngineQueueTests (which
    /// call into `engine.queueSize` and `engine.currentQueueIndex`
    /// directly) compile against the fake the same way they would
    /// against the real `AudioEngine`.
    private(set) var fakeQueue: [PlaybackRequest] = []
    private(set) var fakeQueueIndex: Int = 0

    /// Queue projection — matches `AudioEngine` shape.
    var queueSize: Int { fakeQueue.count }
    var currentQueueIndex: Int { fakeQueue.isEmpty ? -1 : fakeQueueIndex }
    var upcomingRequests: [PlaybackRequest] {
        guard fakeQueueIndex + 1 < fakeQueue.count else { return [] }
        return Array(fakeQueue[(fakeQueueIndex + 1)...])
    }

    /// Optional fake-load helper: when a `.load` or `.crossfade`
    /// arrives, simulate by setting state as if the song finished
    /// loading. Default off so tests can opt-in via `autoLoad`.
    var autoLoad: Bool = true
    var loadDurationSeconds: TimeInterval = 180

    func send(_ command: PlaybackCommand) async {
        sentCommands.append(command)

        // Mirror the real engine's queue bookkeeping so tests that
        // exercise `playQueue` / `enqueueNext` observe equivalent state.
        switch command {
        case .load(let req):
            if fakeQueue.isEmpty {
                fakeQueue = [req]
                fakeQueueIndex = 0
            } else if !fakeQueue.contains(where: { $0.songID == req.songID }) {
                fakeQueue = [req]
                fakeQueueIndex = 0
            } else if let i = fakeQueue.firstIndex(where: { $0.songID == req.songID }) {
                fakeQueueIndex = i
            }
        case .next:
            if fakeQueueIndex + 1 < fakeQueue.count { fakeQueueIndex += 1 }
        case .previous:
            if fakeQueueIndex > 0 { fakeQueueIndex -= 1 }
        default: break
        }

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
