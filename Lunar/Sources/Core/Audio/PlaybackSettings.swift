import Foundation
import Observation

/// User playback preferences (engine-side behaviour).
///
/// Two independent controls:
///
/// 1. **Crossfade duration** — a slider from **0 s** to **12 s**, snapped
///    to a 0.5 s step. Drives how long two songs overlap when `next()`
///    moves the queue forward. **0 s** = direct cut (still gapless when
///    `gaplessEnabled` is on).
///
/// 2. **Gapless playback** — boolean toggle. When **on**, the next song
///    starts as the current ends (zero perceptible gap, with optional
///    crossfade overlap). When **off**, a brief silence separates songs.
///
/// Both values persist to `UserDefaults` and broadcast `onChange` so the
/// `AudioEngine` can mirror them at runtime. Defaults: 6 s crossfade,
/// gapless **on**.
///
/// ## Why a separate @Observable from `AudioEngine`?
///
/// AudioEngine is the *runtime* player (graph state, timers, codecs).
/// PlaybackSettings is the *user intent* — values that survive across
/// launches, edited from a Settings sheet. Keeping them split avoids
/// re-creating the (heavy) AVAudioEngine graph for a slider drag, and
/// matches the Apple Music split between MPPlaybackSettings and the
/// active queue.
@MainActor
@Observable
final class PlaybackSettings {

    static let crossfadeDurationKey = "Lunar.Playback.CrossfadeSeconds"
    static let gaplessKey             = "Lunar.Playback.Gapless"

    /// Inclusive bounds for the slider.
    static let crossfadeRange: ClosedRange<Double> = 0.0...12.0
    /// Discrete step the slider snaps to.
    static let crossfadeStep: Double = 0.5
    /// First-launch default — matches the previous hardcoded value.
    static let defaultCrossfadeSeconds: Double = 6.0
    static let defaultGapless: Bool = true

    // MARK: - Stored values

    var crossfadeDurationSeconds: Double = PlaybackSettings.defaultCrossfadeSeconds {
        didSet {
            UserDefaults.standard.set(
                crossfadeDurationSeconds,
                forKey: Self.crossfadeDurationKey
            )
            onChange?()
        }
    }

    var gaplessEnabled: Bool = PlaybackSettings.defaultGapless {
        didSet {
            UserDefaults.standard.set(
                gaplessEnabled,
                forKey: Self.gaplessKey
            )
            onChange?()
        }
    }

    /// Fires on every persisted change. `LunarAppCoordinator`
    /// installs a closure that mirrors the values into the live
    /// `AudioEngine`. Nil-able so the type stays safe to construct
    /// before the wiring completes.
    var onChange: (() -> Void)?

    // MARK: - Init

    init() {
        if UserDefaults.standard.object(forKey: Self.crossfadeDurationKey) != nil {
            let stored = UserDefaults.standard.double(
                forKey: Self.crossfadeDurationKey
            )
            self.crossfadeDurationSeconds = Self.clamp(stored)
        }
        if UserDefaults.standard.object(forKey: Self.gaplessKey) != nil {
            self.gaplessEnabled = UserDefaults.standard.bool(
                forKey: Self.gaplessKey
            )
        }
    }

    // MARK: - Helpers

    /// Snap a slider / programmatic value to the discrete step + range.
    /// Exposed so the View can validate before round-tripping through
    /// the property setter (avoid didSet recursion from re-clamping).
    static func clamp(_ seconds: Double) -> Double {
        let clipped = min(crossfadeRange.upperBound,
                         max(crossfadeRange.lowerBound, seconds))
        let steps = Int((clipped / crossfadeStep).rounded())
        return Double(steps) * crossfadeStep
    }

    /// Convenience setter for the view — same as direct property
    /// assignment, documented here so call-sites read clearly.
    func updateCrossfade(seconds: Double) {
        crossfadeDurationSeconds = Self.clamp(seconds)
    }

    func updateGapless(_ enabled: Bool) {
        gaplessEnabled = enabled
    }
}
