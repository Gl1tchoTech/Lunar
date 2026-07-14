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
                sleepTimer: sleepTimer
            )
            .environment(theme)
            .environment(audioEngine)
            .environment(sleepTimer)
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

    /// Optional callback the host can use to log a song's natural
    /// completion via `LibraryService.logListenEvent`. Step 5 wires
    /// this up; for Step 4 it's left nil.
    var onSongFinished: ((PlaybackRequest, TimeInterval) -> Void)?

    @State private var didWire = false

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
            }
    }
}
