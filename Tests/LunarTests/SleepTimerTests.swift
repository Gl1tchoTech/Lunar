import XCTest
import Observation
@testable import Lunar

/// Tests for `SleepTimer` — confirms the locked choices (5 / 15 / 30 /
/// 45 / 60 / Off), UserDefaults persistence, ticker lifecycle, and the
/// `onExpire` firing callback. The engine wiring (sleepTimer.onExpire →
/// engine.pause) lives in `LunarAppCoordinator`; here we only need to
/// verify the timer itself behaves correctly in isolation.
@MainActor
final class SleepTimerTests: XCTestCase {

    // Use a per-suite UserDefaults key prefix so tests don't bleed into
    // a real running app's preferences. The storage key is fixed because
    // SleepTimer uses a static — instead we clear UserDefaults before
    // each test so we have a hermetic starting state.
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: SleepTimer.storageKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: SleepTimer.storageKey)
        try await super.tearDown()
    }

    // MARK: - Init + persistence

    func test_init_startsOff_whenNoStoredValue() {
        let timer = SleepTimer()
        XCTAssertEqual(timer.durationMinutes, 0)
        XCTAssertEqual(timer.secondsRemaining, 0)
        XCTAssertFalse(timer.isActive)
    }

    func test_init_restoresStoredDuration() {
        UserDefaults.standard.set(30, forKey: SleepTimer.storageKey)
        let timer = SleepTimer()
        XCTAssertEqual(timer.durationMinutes, 30)
        XCTAssertEqual(timer.secondsRemaining, 30 * 60)
        XCTAssertTrue(timer.isActive)
    }

    func test_supportedMinutes_areTheLockedChoices() {
        XCTAssertEqual(SleepTimer.supportedMinutes, [5, 15, 30, 45, 60])
    }

    // MARK: - Select transitions

    func test_select_5_setsFiveMinutesRemaining() {
        let timer = SleepTimer()
        timer.select(minutes: 5)
        XCTAssertEqual(timer.durationMinutes, 5)
        XCTAssertEqual(timer.secondsRemaining, 300)
        XCTAssertTrue(timer.isActive)
    }

    func test_select_zero_disablesTimer() {
        let timer = SleepTimer()
        timer.select(minutes: 15)
        XCTAssertTrue(timer.isActive)
        timer.select(minutes: 0)
        XCTAssertEqual(timer.durationMinutes, 0)
        XCTAssertEqual(timer.secondsRemaining, 0)
        XCTAssertFalse(timer.isActive)
    }

    func test_select_persistsAcrossInstances() {
        let a = SleepTimer()
        a.select(minutes: 45)
        let b = SleepTimer()
        XCTAssertEqual(b.durationMinutes, 45)
    }

    func test_select_sameDuration_restartsCountdown_fromFull() {
        let timer = SleepTimer()
        timer.select(minutes: 5)
        // Cancel-reset is a public-API helper that sets seconds to 0
        // without changing the user's choice — equivalent to "user
        // manually stopped the countdown via the UI".
        timer.cancel()
        XCTAssertEqual(timer.secondsRemaining, 0)
        // Re-selecting the same value should restart to full.
        timer.select(minutes: 5)
        XCTAssertEqual(timer.secondsRemaining, 300)
    }

    // MARK: - Ticker

    func test_cancel_resetsSecondsRemaining_butKeepsChoice() {
        let timer = SleepTimer()
        timer.select(minutes: 30)
        XCTAssertEqual(timer.secondsRemaining, 30 * 60)
        timer.cancel()
        XCTAssertEqual(timer.durationMinutes, 30, "Cancel must NOT change the user's choice")
        XCTAssertEqual(timer.secondsRemaining, 0)
    }

    func test_ticker_decrementsAndFiresOnExpire() async throws {
        let timer = SleepTimer()
        var expired = false
        timer.onExpire = { expired = true }
        // Inject a 1-second countdown through the `#if DEBUG` hatch.
        timer._debugStart(seconds: 1)
        XCTAssertEqual(timer.secondsRemaining, 1)
        XCTAssertTrue(timer.isActive)
        // Wait long enough for the 1s tick to elapse.
        try await Task.sleep(nanoseconds: 1_400_000_000) // 1.4s
        XCTAssertTrue(expired, "onExpire must fire when countdown hits zero")
        XCTAssertFalse(timer.isActive)
        XCTAssertEqual(timer.secondsRemaining, 0)
    }

    func test_ticker_doesNotFire_afterCancellation() async throws {
        let timer = SleepTimer()
        var expired = false
        timer.onExpire = { expired = true }
        timer._debugStart(seconds: 1)
        timer.cancel()
        try await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertFalse(expired, "Cancelled ticker must not invoke onExpire")
    }
}
