import SwiftUI
import SwiftData

@main
struct LunarApp: App {

    /// App-wide SwiftData container. Built once at launch.
    let container: ModelContainer

    /// Side-effect holder: configures `AVAudioSession` on launch and
    /// pipes interruption / route events to the audio engine.
    /// Treated as a long-lived configured thing — created in `init`,
    /// owned by App, never replaced.
    private let appAudioSession: AppAudioSession

    /// User-selected Player Theme (persisted via UserDefaults).
    @State private var theme = PlayerThemeManager()

    /// Audio engine (AVAudioEngine-backed, real impl) — injected
    /// into the SwiftUI environment via `.environment(audioEngine)`.
    @State private var audioEngine = AudioEngine()

    /// Sleep timer observable.
    @State private var sleepTimer = SleepTimer()

    /// User playback preferences (crossfade + gapless).
    @State private var playbackSettings = PlaybackSettings()

    /// User equalizer preferences (10 bands + on/off + active preset).
    @State private var eqSettings = EQSettings()

    /// App Theme settings (System / Light / Dark + accent color).
    @State private var appThemeSettings = AppThemeSettings()

    init() {
        do {
            container = try ModelContainer(for: LunarSchema.schema)
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
        self.appAudioSession = AppAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            // The coordinator lives between App and RootView so the
            // session→engine + sleepTimer→engine wiring happens in a
            // SwiftUI body where @Environment already has values.
            LunarAppCoordinator(
                audioSession: appAudioSession,
                audioEngine: audioEngine,
                sleepTimer: sleepTimer,
                playbackSettings: playbackSettings,
                eqSettings: eqSettings,
                modelContainer: container
            )
            .environment(theme)
            .environment(audioEngine)
            .environment(sleepTimer)
            .environment(playbackSettings)
            .environment(eqSettings)
            .environment(appThemeSettings)
            .preferredColorScheme(appThemeSettings.mode.colorScheme)
            .tint(appThemeSettings.accent.color)
        }
        .modelContainer(container)
    }

    // NOTE: First-launch EQ-preset seeding is performed in `RootView.task`
    // on the main context, NOT here. Doing it during `App.init` blocks
    // launch and (under Swift 6 strict concurrency) trips an isolation
    // warning because `ModelContext(container)` is a detached background
    // context, not `@MainActor`-isolated like `container.mainContext`.
}

// MARK: - LunarAppCoordinator

/// Wires the audio session + sleep timer into the audio engine. Lives
/// between `LunarApp` (which builds them) and `RootView` (the UI tree).
///
/// Why a view?  `@Environment(AudioEngine.self)` is only safe to read
/// inside a body — doing it in `LunarApp.init` would try to access the
/// environment before injection, which Swift complains about. Putting
/// the wire-up in a view body solves that cleanly.
///
/// Why not `@Bindable` on the engine / timer?  We only need to CALL
/// methods, not read properties, so the observation tracker isn't
/// required here. Plain `let` references are fine.
private struct LunarAppCoordinator: View {

    let audioSession: AppAudioSession
    let audioEngine: AudioEngine
    let sleepTimer: SleepTimer
    let playbackSettings: PlaybackSettings
    let eqSettings: EQSettings
    /// SwiftData container — used by the NowPlayingCenterManager wiring
    /// to resolve a song's artwork bytes on the main context. Kept as
    /// `let` because views recreate the struct on every draw; lifecycle
    /// is owned by `LunarApp` above.
    let modelContainer: ModelContainer

    /// Optional callback the host can use to log a song's natural
    /// completion via `LibraryService.logListenEvent`. Step 5 wires
    /// this up; for Step 4 it's left nil.
    var onSongFinished: ((PlaybackRequest, TimeInterval) -> Void)?

    @State private var didWire = false

    /// Strongly-held reference to the system-hook manager. Keep this
    /// in `@State` so SwiftUI's view-storage keeps the manager alive
    /// across redraws; the audio engine's `onStateChange` closure also
    /// weakly captures it.
    @State private var nowPlayingManager: NowPlayingCenterManager?

    var body: some View {
        RootView()
            .task {
                guard !didWire else { return }
                didWire = true
                audioEngine.attach(session: audioSession)
                sleepTimer.onExpire = { [weak audioEngine] in
                    audioEngine?.pause()
                }
                if let cb = onSongFinished {
                    audioEngine.onSongFinished = cb
                }

                // Mirror PlaybackSettings values into the live
                // AudioEngine. First the warm-up push (uses the
                // settings' stored values, not the engine's compile-
                // time defaults). Then a closure wired into
                // `playbackSettings.onChange` so future slider/toggle
                // edits in the Settings sheet propagate instantly.
                audioEngine.crossfadeDurationSeconds =
                    playbackSettings.crossfadeDurationSeconds
                audioEngine.gaplessEnabled =
                    playbackSettings.gaplessEnabled
                playbackSettings.onChange = { [weak audioEngine] in
                    guard let audioEngine else { return }
                    audioEngine.crossfadeDurationSeconds =
                        playbackSettings.crossfadeDurationSeconds
                    audioEngine.gaplessEnabled =
                        playbackSettings.gaplessEnabled
                }

                // Warm-up push of EQ state — bands are CLAMPED at
                // write time by `EQSettings.bandBinding(at:)`, so we
                // can trust them here. `Task` because `.send` is
                // async (crosses the player-interface command queue).
                let initialBands = eqSettings.bands
                Task { await audioEngine.send(.setEQ(bands: initialBands)) }
                audioEngine.setEQEnabled(eqSettings.isEnabled)

                // Tier 3 — wire MPNowPlayingInfoCenter + MPRemoteCommandCenter
                // through `NowPlayingCenterManager`. The manager's
                // `attach()` registers remote-command handlers + primes
                // the Now Playing info dict so the Lock Screen /
                // Control Center surfaces Lunar as soon as the app
                // starts (even before any song plays).
                let manager = NowPlayingCenterManager(
                    audioEngine: audioEngine,
                    artworkResolver: { id in
                        // Main-context SwiftData fetch. The container's
                        // mainContext is implicitly @MainActor so safe
                        // to read from our closure (which runs on the
                        // main queue via the audio engine callback).
                        if let song = modelContainer.mainContext.model(for: id) as? Song {
                            return song.artwork
                        }
                        return nil
                    }
                )
                nowPlayingManager = manager
                manager.attach()
                audioEngine.onStateChange = { [weak manager] state, _ in
                    manager?.update(state, currentSongID: audioEngine.currentSongID)
                }
            }
            .onChange(of: eqSettings.bands) { _, newBands in
                Task { await audioEngine.send(.setEQ(bands: newBands)) }
            }
            .onChange(of: eqSettings.isEnabled) { _, newEnabled in
                audioEngine.setEQEnabled(newEnabled)
            }
    }
}
