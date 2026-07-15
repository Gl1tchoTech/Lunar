import Foundation
import Observation

/// User queue preferences (`ShuffleMode`, `RepeatMode`).
///
/// Mirrors the `PlaybackSettings` template: stored on the value, written
/// to `UserDefaults` on assignment, fired via `onChange`. `LunarAppCoordinator`
/// installs a closure into `onChange` so the live `AudioEngine` keeps
/// its internal mirrors (`shuffleMode`, `repeatMode`) in sync without
/// touching the (heavy) AVAudioEngine graph.
///
/// ## Why an external `@Observable` instead of fields on `AudioEngine`?
///
/// 1. `AudioEngine` is rebuilt only when the graph crashes; user
///    preferences are *conceptually* separate and should survive an
///    engine re-creation.
/// 2. `AudioEngine` would otherwise need to do its own UserDefaults I/O
///    just to remember a toggle, mixing presentation state into the
///    runtime player.
/// 3. `LunarAppCoordinator.task` runs once at launch — separating the
///    preferences from the engine keeps that wiring one closure per
///    setting, matching the existing `PlaybackSettings` pattern.
@MainActor
@Observable
final class QueueSettings {

    static let shuffleKey = "Lunar.Queue.Shuffle"
    static let repeatKey  = "Lunar.Queue.Repeat"

    static let defaultShuffle: ShuffleMode = .off
    static let defaultRepeat:  RepeatMode  = .off

    // MARK: - Stored values

    var shuffleMode: ShuffleMode = QueueSettings.defaultShuffle {
        didSet {
            UserDefaults.standard.set(shuffleMode.rawValue, forKey: Self.shuffleKey)
            onChange?()
        }
    }

    var repeatMode: RepeatMode = QueueSettings.defaultRepeat {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: Self.repeatKey)
            onChange?()
        }
    }

    /// Fires on every persisted change. `LunarAppCoordinator` installs
    /// a closure that mirrors the values into the live `AudioEngine`.
    /// `nil` until wiring completes.
    var onChange: (() -> Void)?

    // MARK: - Init

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.shuffleKey),
           let mode = ShuffleMode(rawValue: raw) {
            self.shuffleMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: Self.repeatKey),
           let mode = RepeatMode(rawValue: raw) {
            self.repeatMode = mode
        }
    }

    // MARK: - Convenience

    /// Cycle through the repeat modes on user tap (`off → all → one → off`).
    /// Apple Music order. Single method so the cycle is enforced from
    /// one place.
    func cycleRepeatMode() {
        switch repeatMode {
        case .off:    repeatMode = .all
        case .all:    repeatMode = .one
        case .one:    repeatMode = .off
        }
    }

    /// Binary toggle for shuffle (`off ↔ on`).
    func toggleShuffleMode() {
        shuffleMode = shuffleMode == .off ? .on : .off
    }
}
