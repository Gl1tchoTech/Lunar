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

    /// Pre-decoded file used by the active player node. `nil` after
    /// `pause()` / `stop()`. Cached so a `play()` after pause
    /// doesn't need to re-read disk.
    private var currentFile: AVAudioFile?
    private var currentNode: AVAudioPlayerNode

    private let engine = AVAudioEngine()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let eq = EQController.makeUnit()

    // MARK: - Timers / subscriptions

    private var session: AppAudioSession?
    private var sessionEvents: AnyCancellable?
    private var progressTimer: AnyCancellable?
    private var crossfadeTimer: AnyCancellable?

    private let progressTimerInterval: TimeInterval = 0.1
    private let crossfadeTimerInterval: TimeInterval = 1.0 / 60.0

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
        case .setEQ(let bands):     EQController.apply(bands: bands, to: eq)
        }
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
    }

    func pause() {
        currentNode.pause()
        progressTimer?.cancel()
        progressTimer = nil
        state.isPlaying = false
    }

    func togglePlayPause() {
        state.isPlaying ? pause() : play()
    }

    func next() {
        // Real queue logic will arrive in Step 5 (Now Playing + queue UI).
        // For now we expose the hook so upcoming `setNext(songID:)` can
        // hand off the next file here.
        pause()
        state.currentTime = 0
    }

    func previous() {
        // Step 5 will use the song history for "play previous".
        guard state.currentTime > 3 else { return }
        seek(to: 0)
    }

    func seek(to time: TimeInterval) {
        guard currentFile != nil else { return }
        // Re-schedule from the new offset on the same node.
        scheduleCurrentNode(from: time)
        currentNode.play()
        state.currentTime = time
    }

    func setMasterVolume(_ volume: Float) {
        let clamped = min(1.0, max(0.0, volume))
        engine.mainMixerNode.outputVolume = clamped
        state.volume = clamped
    }

    // MARK: - Load + crossfade

    /// Read the file off-thread, then schedule it on the active node
    /// on the main thread.
    private func load(request: PlaybackRequest) async {
        let url = request.fileURL
        let file: AVAudioFile? = await Task.detached(priority: .userInitiated) {
            try? AVAudioFile(forReading: url)
        }.value

        guard let file else {
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
    }

    /// Pre-decodes the next file on a background task and ramps
    /// `current` → 0 / `next` → 1 over `durationSeconds`.
    private func crossfade(to request: PlaybackRequest, durationSeconds: Double) async {
        let url = request.fileURL
        let nextFile: AVAudioFile? = await Task.detached(priority: .userInitiated) {
            try? AVAudioFile(forReading: url)
        }.value

        guard let nextFile else { return }

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
        // No auto-advance to a real queue yet (Step 5). Just stop cleanly.
        progressTimer?.cancel()
        state.isPlaying = false
        state.currentTime = 0
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
