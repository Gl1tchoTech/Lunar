import Foundation
import AVFoundation
import Observation
import Combine

/// Real `AVAudioEngine`-backed player.
///
/// Graph topology (frozen at `init`, **never** altered at runtime — see
/// [Gemini review / blocker #1](https://github.com/Gl1tchoTech/Lunar)):
///
/// ```
/// playerA ─┐
///          ├─▶ timePitch ─▶ eq ─▶ engine.mainMixerNode ─▶ output
/// playerB ─┘
/// ```
///
/// `playerA` and `playerB` are double-buffered to support **gapless
/// crossfade**: while A is playing song X, we already pre-load B for
/// song Y + ramp volumes via a 60Hz timer.
///
/// Concurrency:
/// - **Main actor**: holds `@Observable` `state`, owns the engine + nodes,
///   drives UI-bound timers (progress + crossfade).
/// - **`Task.detached(priority: .userInitiated)`**: `AVAudioFile(forReading:)`
///   + `playerNode.scheduleFile(_:...)`. Crosses actors with **only**
///   `URL` and `String` values — never `Song`/`PersistentIdentifier`.
@MainActor
@Observable
final class AudioEngine: AudioPlayerInterface {

    /// Snapshot published to SwiftUI views. Drivers should call
    /// `publishState()` after every mutation.
    private(set) var state = PlayerState()

    /// Currently loaded song's identifier. Use to map back to a
    /// `Song` in the main context for UI display.
    private(set) var currentSongID: PersistentIdentifier?

    /// In-memory playback queue. Holds the full ordered list of upcoming
    /// requests plus a pointer to the one we're playing. Replaced
    /// whenever the user starts a new "Play All" / "Play Song" / "Shuffle".
    private var queue: [PlaybackRequest] = []
    private var queueIndex: Int = 0

    /// Pre-decoded file used by the active player node. `nil` after
    /// `pause()` / `stop()`. Cached so a `play()` after pause
    /// doesn't need to re-read disk.
    private var currentFile: AVAudioFile?
    private var currentNode: AVAudioPlayerNode

    /// Set true while a `.load` or `.crossfade` is in flight. Prevents
    /// rapid `next()` / `previous()` taps from queuing two crossfade
    /// commands on top of each other.
    private var isTransitioning: Bool = false

    /// Optional callback fired when a song naturally completes
    /// (not when the user manually pauses). The host can use this
    /// to log a `ListenEvent` via `LibraryService.logListenEvent`.
    var onSongFinished: ((PlaybackRequest, TimeInterval) -> Void)?

    /// Optional callback fired whenever `state` changes (after a
    /// `PlayerState.Equatable` diff against the last notified value).
    /// Used by `NowPlayingCenterManager` to mirror state into
    /// `MPNowPlayingInfoCenter` so the Lock Screen / Control Center
    /// stays in sync with `currentTime` (the progress tick fires every
    /// 0.1 s; consumers can decide whether they care about that
    /// granularity or want to debounce further).
    ///
    /// **When it fires**: any direct mutation of `state.currentTitle /
    /// currentArtist / currentTime / duration / isPlaying / volume`,
    /// plus the per-tick progress update. Compared with the previous
    /// snapshot — if nothing changed the callback is suppressed.
    var onStateChange: ((PlayerState, _ songID: PersistentIdentifier?) -> Void)?

    /// Last snapshot passed to `onStateChange`. Used for diff-skip when
    /// only `currentTime` ticks forward (the lock-screen scrubber is
    /// happy with ~0.5 s cadence; pushing 10×/s is wasteful).
    private var lastNotifiedState: PlayerState?

    private let engine = AVAudioEngine()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let eq = EQController.makeUnit()

    /// Cached copy of the most recently applied band array. Used by
    /// `setEQEnabled(_:)` to restore the user's tuning when the EQ
    /// is re-enabled after a bypass.
    private var lastAppliedBands: [Float] = Array(repeating: 0, count: 10)

    // MARK: - Timers / subscriptions

    // MARK: - Engine-mirrored playback preferences
    //
    // Mirrored from `PlaybackSettings` at launch and on every
    // `onChange` callback via `LunarAppCoordinator`. Public-read so
    // tests can verify sync; writes happen through that hook (not
    // direct property sets from views).

    /// Default crossfade duration for queued `next()` transitions.
    /// 0 = direct cut (gapless). Stepped 0…12 s in 0.5 s increments
    /// via `PlaybackSettings.crossfadeStep`.
    var crossfadeDurationSeconds: Double = 6

    /// When true, `next()` performs a continuous swap so there is no
    /// perceptible silence between songs (with optional crossfade
    /// overlap driven by `crossfadeDurationSeconds`). When false,
    /// `next()` stops the current node + reloads the next — a small
    /// gap separates tracks.
    var gaplessEnabled: Bool = true

    /// Whether `playQueue(_:startIndex:)` reshuffles the passed list,
    /// keeping the song resolved by `startIndex` pinned to position 0
    /// (Apple Music behaviour). Default **`.off`** — caller order is
    /// preserved. Mirrored from `QueueSettings.shuffleMode` via
    /// `LunarAppCoordinator.onChange`.
    var shuffleMode: ShuffleMode = .off

    /// End-of-queue looping behaviour. Default **`.off`** — playback
    /// pauses when the queue ends. **`.one`** re-seeks the current song
    /// to `0` and replays it (still fires `onSongFinished` once per
    /// natural end so `ListenEvent`s keep recording). **`.all`** wraps
    /// the queue pointer back to `0` and continues. Mirrored from
    /// `QueueSettings.repeatMode` via `LunarAppCoordinator.onChange`.
    var repeatMode: RepeatMode = .off

    private var session: AppAudioSession?
    private var sessionEvents: AnyCancellable?
    private var progressTimer: AnyCancellable?
    private var crossfadeTimer: AnyCancellable?

    private let progressTimerInterval: TimeInterval = 0.1
    private let crossfadeTimerInterval: TimeInterval = 1.0 / 60.0

    /// Push `state` to `onStateChange` if it differs from the last
    /// notified value (PlayerState is Equatable). Called from every
    /// state-mutating site so the Lock Screen / Control Center can
    /// stay in sync without polling.
    private func notifyStateChange() {
        let new = state
        guard new != lastNotifiedState else { return }
        lastNotifiedState = new
        onStateChange?(new, currentSongID)
    }

    // MARK: - Init

    init() {
        self.currentNode = playerA
        installGraph()
    }

    /// Hook up the AVAudioSession as a separate step so views can keep
    /// a pure `AudioEngine()` for previews and tests.
    func attach(session: AppAudioSession) {
        self.session = session
        sessionEvents = session.events.sink { [weak self] event in
            self?.handleSessionEvent(event)
        }
    }

    /// Start the underlying `AVAudioEngine`. Safe to call more than
    /// once (no-op on subsequent calls).
    private func ensureEngineStarted() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
    }

    /// Build the player → time-pitch → EQ → main mixer graph once at
    /// init. **Never** connect/disconnect nodes after this point —
    /// AVAudioEngine fatally asserts on topology mutations mid-play.
    private func installGraph() {
        engine.attach(playerA)
        engine.attach(playerB)
        engine.attach(timePitch)
        engine.attach(eq)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 2
        )

        engine.connect(playerA, to: timePitch, format: format)
        engine.connect(playerB, to: timePitch, format: format)
        engine.connect(timePitch, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
    }

    // MARK: - AudioPlayerInterface

    func send(_ command: PlaybackCommand) async {
        switch command {
        case .play:                 play()
        case .pause:                pause()
        case .togglePlayPause:      togglePlayPause()
        case .next:                 next()
        case .previous:             previous()
        case .seek(let t):          seek(to: t)
        case .load(let req):        await load(request: req)
        case .crossfade(let req, let secs):
            await crossfade(to: req, durationSeconds: secs)
        case .setVolume(let v):     setMasterVolume(v)
        case .setEQ(let bands):     applyEQ(bands: bands)
        }
    }

    /// Public bypass toggle. Re-applies the cached bands when re-
    /// enabled so the user's tuning survives a temporary bypass.
    /// Called by `LunarAppCoordinator` via `.onChange(of:)`.
    func setEQEnabled(_ enabled: Bool) {
        if enabled {
            applyEQ(bands: lastAppliedBands)
        } else {
            EQController.bypass(eq)
        }
    }

    /// Internal: apply bands + cache the *clamped* values for later
    /// bypass-restore. Avoids re-calling the (expensive) AVAudioUnitEQ
    /// band-setter twice per change.
    private func applyEQ(bands: [Float]) {
        let clamped = bands.map { min(12.0, max(-12.0, $0)) }
        EQController.apply(bands: clamped, to: eq)
        lastAppliedBands = clamped
    }

    // MARK: - Commands (public)

    func play() {
        guard currentFile != nil else { return }
        do {
            try ensureEngineStarted()
            currentNode.play()
            startProgressTicker()
            state.isPlaying = true
        } catch {
            assertionFailure("AudioEngine.start failed: \(error)")
        }
        notifyStateChange()
    }

    func pause() {
        currentNode.pause()
        progressTimer?.cancel()
        progressTimer = nil
        state.isPlaying = false
        notifyStateChange()
    }

    func togglePlayPause() {
        state.isPlaying ? pause() : play()
    }

    /// Advance to the **next queued song**. If at the end of the
    /// queue, pauses the engine and resets the current time. Internally
    /// fires `Task { await ... }` so the public method remains sync —
    /// callers (transport buttons) don't have to `await`.
    ///
    /// Gated by `isTransitioning` so rapid taps don't pile up multiple
    /// in-flight crossfade commands.
    func next() {
        guard !isTransitioning else { return }
        guard queueIndex + 1 < queue.count else {
            pause()
            state.currentTime = 0
            notifyStateChange()
            return
        }
        queueIndex += 1
        let request = queue[queueIndex]
        isTransitioning = true
        Task {
            if self.gaplessEnabled {
                // Crossfade path: 0 s = pure swap-with-no-gap (Δ on
                // `rampCrossfade` handles the divide-by-zero), > 0 s =
                // classic overlap fade.
                await self.send(.crossfade(
                    request,
                    durationSeconds: self.crossfadeDurationSeconds
                ))
            } else {
                // Cut-and-reload path: brief silence between songs.
                await self.send(.load(request))
                self.play()
            }
            self.isTransitioning = false
        }
    }

    /// Walk back. If we're deeper than 3 seconds into the current
    /// song, restart it instead of going to the previous.
    func previous() {
        guard !isTransitioning else { return }
        if state.currentTime > 3 {
            seek(to: 0)
            return
        }
        guard queueIndex > 0 else {
            seek(to: 0)
            return
        }
        queueIndex -= 1
        let request = queue[queueIndex]
        isTransitioning = true
        Task {
            await self.send(.load(request))
            self.play()
            self.isTransitioning = false
        }
    }

    func seek(to time: TimeInterval) {
        guard currentFile != nil else { return }
        // Re-schedule from the new offset on the same node.
        scheduleCurrentNode(from: time)
        currentNode.play()
        state.currentTime = time
        notifyStateChange()
    }

    func setMasterVolume(_ volume: Float) {
        let clamped = min(1.0, max(0.0, volume))
        engine.mainMixerNode.outputVolume = clamped
        state.volume = clamped
        notifyStateChange()
    }

    // MARK: - Queue

    /// Replace the in-memory queue and start playback at `startIndex`.
    /// Subsequent `next()` / `previous()` / song-finished events walk
    /// this queue.
    func playQueue(_ requests: [PlaybackRequest], startIndex: Int = 0) {
        guard !requests.isEmpty else { return }
        let (newQueue, newIndex) = Self.buildQueue(
            requests: requests,
            startIndex: startIndex,
            shuffleMode: shuffleMode
        )
        queue = newQueue
        queueIndex = newIndex
        let first = queue[queueIndex]
        Task { await self.send(.load(first)); self.play() }
    }

    /// Pure helper that builds the in-memory queue based on the shuffle
    /// mode. Lifted out of `playQueue(_:startIndex:)` so unit tests can
    /// verify shuffle-pinning behaviour without spinning up
    /// `AVAudioEngine`.
    ///
    /// Returns `(queue, queueIndex)`. `ShuffleMode.on` with ≥ 2 songs
    /// pins the song at `startIndex` to position 0 and shuffles the
    /// rest (Apple Music behaviour). Otherwise the queue is taken in
    /// call-site order.
    static func buildQueue(
        requests: [PlaybackRequest],
        startIndex: Int,
        shuffleMode: ShuffleMode
    ) -> (queue: [PlaybackRequest], queueIndex: Int) {
        guard !requests.isEmpty else { return ([], 0) }
        let clamped = max(0, min(startIndex, requests.count - 1))
        if shuffleMode == .on, requests.count > 1 {
            let pinned = requests[clamped]
            let tail = requests.enumerated()
                .filter { $0.offset != clamped }
                .map(\.element)
                .shuffled()
            return ([pinned] + tail, 0)
        }
        return (requests, clamped)
    }

    /// Append a song to play **after the current song**, then continue
    /// through the rest of the queue. Safe to call when the queue is
    /// empty — in that case the request becomes the entire queue
    /// starting at index 0.
    ///
    /// `insertAt = min(queueIndex + 1, queue.count)` (NOT `max`!) — earlier
    /// versions accidentally pushed "Play Next" to the very back of the
    /// queue because `queueIndex + 1 < queue.count` makes `max(...)`
    /// collapse to `queue.count`. Tracked under the post-Step-4 review.
    func enqueueNext(_ request: PlaybackRequest) {
        if queue.isEmpty {
            queue = [request]
            queueIndex = 0
            // Don't auto-play; user expects to keep listening to current song
            // (or silence) until they tap Play. Caller can call `play()`
            // separately if needed.
            return
        }
        let insertAt = min(queueIndex + 1, queue.count)
        queue.insert(request, at: insertAt)
    }

    /// Total queue size + current index, exposed for the Now Playing UI.
    var queueSize: Int { queue.count }
    var currentQueueIndex: Int { queue.isEmpty ? -1 : queueIndex }

    /// The full queue (read-only projection), exposed so the Now Playing
    /// UI can show upcoming tracks.
    var upcomingRequests: [PlaybackRequest] {
        guard queueIndex >= 0, queueIndex + 1 < queue.count else { return [] }
        return Array(queue[(queueIndex + 1)...])
    }

    // MARK: - Load + crossfade

    /// Resolve the request's file. We open `AVAudioFile` synchronously
    /// on the main actor — the open itself is microsecond-cheap; the
    /// real I/O happens lazily during `scheduleSegment` / `scheduleFile`.
    /// Doing it synchronously keeps `AVAudioFile` (which is not `Sendable`)
    /// out of any cross-actor return path, so Swift 6 strict concurrency
    /// stays happy.
    private func load(request: PlaybackRequest) async {
        let url = request.fileURL
        guard let file = try? AVAudioFile(forReading: url) else {
            assertionFailure("AudioEngine failed to read \(url.lastPathComponent)")
            return
        }

        currentFile = file
        currentSongID = request.songID
        state.currentTitle = request.title
        state.currentArtist = request.artist
        state.duration = file.length > 0 ? TimeInterval(file.length) / file.processingFormat.sampleRate : request.duration
        state.currentTime = 0

        scheduleCurrentNode(from: 0)
        notifyStateChange()
    }

    /// Pre-decodes the next file on the main thread (file open is cheap)
    /// and ramps `current` → 0 / `next` → 1 over `durationSeconds`.
    private func crossfade(to request: PlaybackRequest, durationSeconds: Double) async {
        let url = request.fileURL
        guard let nextFile = try? AVAudioFile(forReading: url) else { return }

        let nextNode: AVAudioPlayerNode = (currentNode === playerA) ? playerB : playerA
        nextNode.volume = 0
        try? ensureEngineStarted()
        nextNode.scheduleFile(nextFile, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleNextNodeCompleted()
            }
        }
        nextNode.play()

        rampCrossfade(over: durationSeconds, from: currentNode, to: nextNode)

        // Swap roles.
        currentFile = nextFile
        currentNode = nextNode
        currentSongID = request.songID
        state.currentTitle = request.title
        state.currentArtist = request.artist
        state.duration = nextFile.length > 0
            ? TimeInterval(nextFile.length) / nextFile.processingFormat.sampleRate
            : request.duration
        state.currentTime = 0
        state.isPlaying = true
        startProgressTicker()
        notifyStateChange()
    }

    private func scheduleCurrentNode(from offset: TimeInterval) {
        guard let file = currentFile else { return }
        currentNode.stop()
        let frameOffset = AVAudioFramePosition(offset * file.processingFormat.sampleRate)
        let totalFrames = file.length
        guard totalFrames > 0, frameOffset < totalFrames else { return }
        let framesToPlay = AVAudioFrameCount(totalFrames - frameOffset)
        currentNode.scheduleSegment(
            file,
            startingFrame: frameOffset,
            frameCount: framesToPlay,
            at: nil
        )
    }

    private func rampCrossfade(
        over duration: Double,
        from outgoing: AVAudioPlayerNode,
        to incoming: AVAudioPlayerNode
    ) {
        crossfadeTimer?.cancel()

        // Duration ≤ 0 (e.g. user set crossfade slider to Off) — no
        // timer needed. Snap outgoing to silent and incoming to full
        // volume, stop the outgoing node, and bail. Avoids
        // divide-by-zero in `elapsed / duration` below when duration
        // is exactly 0.
        guard duration > 0 else {
            outgoing.volume = 0
            incoming.volume = 1
            outgoing.stop()
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        crossfadeTimer = Timer.publish(every: crossfadeTimerInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                let t = min(1.0, max(0.0, elapsed / duration))
                outgoing.volume = Float(1.0 - t)
                incoming.volume = Float(t)
                if t >= 1.0 {
                    outgoing.stop()
                    self.crossfadeTimer?.cancel()
                    self.crossfadeTimer = nil
                }
            }
    }

    private func handleNextNodeCompleted() {
        // Auto-advance: if the queue has more, step into `next()`.
        // Otherwise, end the session cleanly.
        progressTimer?.cancel()

        // Repeat.one — replay current song from 0. Beats `next()` so it
        // wins even when more songs exist in the queue. Still fires
        // `onSongFinished` once per natural completion so ListenEvent
        // recording stays correct.
        if repeatMode == .one, currentFile != nil, queueIndex >= 0, queueIndex < queue.count {
            let finishedSong = queue[queueIndex]
            onSongFinished?(finishedSong, state.duration)
            scheduleCurrentNode(from: 0)
            currentNode.play()
            state.currentTime = 0
            notifyStateChange()
            startProgressTicker()
            return
        }

        let hasMore = queueIndex + 1 < queue.count
        let validIndex = queueIndex >= 0 && queueIndex < queue.count

        if hasMore, validIndex {
            let finishedSong = queue[queueIndex]
            onSongFinished?(finishedSong, state.duration)
            next()
            return
        }

        // End of queue. Repeat.all wraps back to index 0; .off pauses.
        if repeatMode == .all, validIndex, !queue.isEmpty {
            let finishedSong = queue[queueIndex]
            onSongFinished?(finishedSong, state.duration)
            queueIndex = 0
            let request = queue[queueIndex]
            Task {
                await self.send(.load(request))
                self.play()
            }
            return
        }

        state.isPlaying = false
        state.currentTime = 0
        notifyStateChange()
    }

    // MARK: - Progress / state

    private func startProgressTicker() {
        progressTimer?.cancel()
        progressTimer = Timer.publish(every: progressTimerInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickProgress() }
    }

    private func tickProgress() {
        guard let lastTime = currentNode.lastRenderTime,
              let playerTime = currentNode.playerTime(forNodeTime: lastTime),
              let file = currentFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let seconds = Double(playerTime.sampleTime) / max(sampleRate, 1)
        state.currentTime = min(seconds, state.duration)
        // No diff guard here: the manager layered on top will do its
        // own Equatable check, and we want every wallclock-shaped tick
        // to bubble up so the scrubber renders smoothly.
        notifyStateChange()
    }

    // MARK: - Session events

    private func handleSessionEvent(_ event: AudioEvent) {
        switch event {
        case .interruptionBegan:
            pause()
        case .interruptionEnded(let shouldResume):
            if shouldResume { play() }
        case .routeChanged(let reason):
            // Old device-out (e.g. headphones unplugged): pause to
            // honour Apple's "duck + pause on route change" convention.
            if reason == .oldDeviceUnavailable { pause() }
        }
    }
}
