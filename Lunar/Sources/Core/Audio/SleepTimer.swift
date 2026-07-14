import Foundation
import Observation
import Combine

/// User-configured sleep timer for the audio player.
///
/// Concrete choices per locked decisions: 5 / 15 / 30 / 45 / 60 minutes
/// or **Off**.
@MainActor
@Observable
final class SleepTimer {

    /// Off state plus the discrete minute choices (no granular typing —
    /// ships exactly what the Settings UI exposes).
    static let supportedMinutes: [Int] = [5, 15, 30, 45, 60]

    static let storageKey = "Lunar.SleepTimerDuration"

    /// Currently selected duration in minutes. `0` = off. Setting this
    /// restarts the timer immediately.
    var durationMinutes: Int {
        didSet { UserDefaults.standard.set(durationMinutes, forKey: Self.storageKey) }
    }

    /// Seconds remaining until pause. `0` when off. Read by the UI to
    /// render the "Sleep in 4:32" badge.
    private(set) var secondsRemaining: Int = 0

    /// Invoked **once** when the countdown hits zero. Caller wires it
    /// to `AudioEngine.pause()`. Using a closure keeps `SleepTimer`
    /// completely decoupled from the audio engine.
    var onExpire: (() -> Void)?

    private var ticker: AnyCancellable?

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.storageKey)
        self.durationMinutes = stored > 0 ? stored : 0
        recomputeRemaining()
    }

    /// Switch duration and (re)start the countdown. If `minutes == 0`,
    /// the timer is removed and `secondsRemaining = 0`.
    func select(minutes: Int) {
        durationMinutes = minutes
        recomputeRemaining()
        startIfNeeded()
    }

    /// Cancel an in-progress timer without changing the user's choice.
    func cancel() {
        ticker?.cancel()
        ticker = nil
        secondsRemaining = 0
    }

    private func recomputeRemaining() {
        if durationMinutes > 0 {
            secondsRemaining = durationMinutes * 60
        } else {
            secondsRemaining = 0
        }
    }

    private func startIfNeeded() {
        ticker?.cancel()
        guard secondsRemaining > 0 else {
            ticker = nil
            return
        }
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            ticker?.cancel()
            ticker = nil
            onExpire?()
        }
    }
}
