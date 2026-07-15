import Foundation
import Observation
import SwiftUI
import SwiftData

/// User-facing equalizer state.
///
/// Holds:
/// - The **current 10 band gains** (-12 ... +12 dB each)
/// - **`isEnabled`** (mock bypass): when false, the engine sets all
///   `AVAudioUnitEQ` bands to `bypass = true` so the audio passes
///   through untouched.
/// - The **`currentPresetID`**: tied to the active preset for
///   highlight in the picker; `nil` once the user nudges any band
///   off the original preset values (so we know the state is
///   "Custom").
///
/// ## Mirroring to AudioEngine
/// `EQSettings` deliberately does **NOT** reach into the
/// `AudioEngine` directly. The mirror lives in `LunarAppCoordinator`
/// via SwiftUI's `.onChange(of:)`, which only fires on real changes
/// and lets us avoid constructing escaping closures in a model
/// class.
///
/// Custom detection is cheap: setting `currentPresetID = nil` on
/// every band change is an in-memory write and runs in nanoseconds.
@MainActor
@Observable
final class EQSettings {

    /// 10 band gains in dB. Default 0 (flat response). Range
    /// bounded by `EQController.isoBandCentersHz.count` and clamped
    /// to ±12 dB before being sent to the engine.
    ///
    /// MainActor-isolated by default (enclosing class is
    /// `@MainActor @Observable`). The `@Observable` macro's
    /// ObservationRegistrar hands out MainActor-isolated accessors
    /// for stored properties under strict concurrency, and the
    /// Swift compiler explicitly disallows `nonisolated` on
    /// stored properties of @Observable types — the regression
    /// that broke `21774b5`. So the diagnostic fix had to live at
    /// the access site instead: `EqualizerView.isEnabledFooter`
    /// and `EqualizerView.isAllFlat` carry explicit `@MainActor`
    /// annotations that satisfy the compiler and keep SwiftUI
    /// view-context reads of `bands` clean.
    var bands: [Float] {
        didSet {
            // Keep the array length sane if a future migration ever
            // trims it; never let the engine see fewer than 10 bands.
            if bands.count != EQController.isoBandCentersHz.count {
                bands = Array(repeating: 0, count: EQController.isoBandCentersHz.count)
                return
            }
            // Nudge off any active preset highlight — the user is
            // diverging from the picked tuning.
            currentPresetID = nil
        }
    }

    /// When false, the EQ is bypassed (audio passes through). The
    /// default is `true` (bands are engaged). MainActor-isolated
    /// by virtue of the enclosing `@MainActor @Observable` class —
    /// `nonisolated` is disallowed on stored properties of
    /// @Observable types under strict concurrency. See `bands`
    /// for the full rationale.
    var isEnabled: Bool = true

    /// Currently applied preset. `nil` = no preset / "Custom".
    /// `PersistentIdentifier` is `Sendable` so the value itself is
    /// safe to pass across actors, but the property stays
    /// MainActor-isolated because the enclosing class is. See
    /// `bands` for the full rationale.
    var currentPresetID: PersistentIdentifier?

    init() {
        self.bands = Array(repeating: 0, count: EQController.isoBandCentersHz.count)
    }

    // MARK: - Per-band SwiftUI binding

    /// Returns a `Binding<Float>` for `bands[index]`. Used by
    /// per-band slider views because iOS 17 SwiftUI's
    /// `@Bindable` doesn't expand `bands[index]` into a working
    /// two-way binding out of the box. The custom get/set re-assigns
    /// `bands` so `@Observable`'s tracking + `bands.didSet` fire.
    ///
    /// Captures `self.bands` explicitly inside the closures —
    /// required by Swift 6 strict-concurrency rules because
    /// `Binding<Float>`'s `get`/`set` cross context boundaries,
    /// so the macro-expanded MainActor-isolated accessor for
    /// `bands` must be reached via `self.` (the only allowed
    /// escape hatch). Reads of `self.bands` from these closures
    /// still run on MainActor (no actor hop) but the explicit
    /// `self.` is what silences the diagnostic under
    /// `SWIFT_STRICT_CONCURRENCY: minimal`.
    func bandBinding(at index: Int) -> Binding<Float> {
        Binding(
            get: {
                guard self.bands.indices.contains(index) else { return 0 }
                return self.bands[index]
            },
            set: { newValue in
                guard self.bands.indices.contains(index) else { return }
                var updated = self.bands
                updated[index] = newValue
                self.bands = updated
            }
        )
    }

    // MARK: - Mutations

    /// Snap to a stored preset's bands. Sets `currentPresetID` so the
    /// picker highlights the right pill.
    func apply(preset: EQPreset) {
        let copy = padOrTrim(preset.bands)
        bands = copy
        currentPresetID = preset.persistentModelID
    }

    /// Explicit reset to flat — zeros all bands + clear
    /// `currentPresetID`. `isEnabled` stays where the user set it.
    func reset() {
        bands = Array(repeating: 0, count: EQController.isoBandCentersHz.count)
    }

    // MARK: - Helpers

    /// Pad shorter arrays with zeros; trim longer arrays. Defensive
    /// only — `EQPreset.bands` validation lives upstream — but
    /// pre-empting bad data avoids a crash at the AV engine layer.
    private func padOrTrim(_ source: [Float]) -> [Float] {
        let targetCount = EQController.isoBandCentersHz.count
        guard source.count != targetCount else { return source }
        if source.count > targetCount {
            return Array(source.prefix(targetCount))
        }
        var padded = source
        padded.append(contentsOf: Array(repeating: 0, count: targetCount - source.count))
        return padded
    }
}

// MARK: - Constants

extension EQSettings {
    /// -12 dB clamp. Mirrors `EQController`'s clamp so the bounds are
    /// the only knob the slider view needs to read.
    static let bandRange: ClosedRange<Float> = -12.0...12.0

    /// Default band step (UI granularity). 0.5 dB matches the visual
    /// granularity most music players expose.
    static let bandStep: Float = 0.5
}
