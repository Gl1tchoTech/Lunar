import XCTest
import Observation
@testable import Lunar

/// Tests for `PlaybackSettings` — the user-facing playback preferences
/// (crossfade duration + gapless toggle). Confirms defaults, restoration
/// from `UserDefaults`, clamping at the slider's boundaries, and the
/// `onChange` callback that mirrors changes into the live `AudioEngine`.
@MainActor
final class PlaybackSettingsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: PlaybackSettings.crossfadeDurationKey)
        UserDefaults.standard.removeObject(forKey: PlaybackSettings.gaplessKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: PlaybackSettings.crossfadeDurationKey)
        UserDefaults.standard.removeObject(forKey: PlaybackSettings.gaplessKey)
        try await super.tearDown()
    }

    // MARK: - Defaults + bounds

    func test_init_defaultsAreSixAndGaplessOn() {
        let s = PlaybackSettings()
        XCTAssertEqual(s.crossfadeDurationSeconds, 6.0, accuracy: 0.0001)
        XCTAssertTrue(s.gaplessEnabled)
    }

    func test_supportedConstants_matchTheBriefRang() {
        XCTAssertEqual(PlaybackSettings.crossfadeRange.lowerBound, 0.0)
        XCTAssertEqual(PlaybackSettings.crossfadeRange.upperBound, 12.0)
        XCTAssertEqual(PlaybackSettings.crossfadeStep, 0.5)
    }

    func test_clamp_clampsAboveMaxToTwelve() {
        XCTAssertEqual(PlaybackSettings.clamp(99), 12.0, accuracy: 0.0001)
    }

    func test_clamp_clampsBelowMinToZero() {
        XCTAssertEqual(PlaybackSettings.clamp(-1), 0.0, accuracy: 0.0001)
    }

    func test_clamp_snapsToHalfStep() {
        XCTAssertEqual(PlaybackSettings.clamp(5.7), 5.5, accuracy: 0.0001)
        XCTAssertEqual(PlaybackSettings.clamp(5.4), 5.5, accuracy: 0.0001)
        XCTAssertEqual(PlaybackSettings.clamp(5.25), 5.5, accuracy: 0.0001)
    }

    // MARK: - Persistence

    func test_init_restoresStoredCrossfade() {
        UserDefaults.standard.set(3.5, forKey: PlaybackSettings.crossfadeDurationKey)
        let s = PlaybackSettings()
        XCTAssertEqual(s.crossfadeDurationSeconds, 3.5, accuracy: 0.0001)
    }

    func test_init_restoresStoredZeroCrossfade() {
        // 0 is a valid slider value (fade disabled). UserDefaults'
        // `integer(forKey:)` returns 0 when missing, so we must check
        // object existence before deciding.
        UserDefaults.standard.set(0.0, forKey: PlaybackSettings.crossfadeDurationKey)
        let s = PlaybackSettings()
        XCTAssertEqual(s.crossfadeDurationSeconds, 0.0, accuracy: 0.0001)
    }

    func test_init_restoresStoredGaplessOff() {
        UserDefaults.standard.set(false, forKey: PlaybackSettings.gaplessKey)
        let s = PlaybackSettings()
        XCTAssertFalse(s.gaplessEnabled)
    }

    func test_init_clampsAllowingRestoredValueAboveDefault() {
        UserDefaults.standard.set(20, forKey: PlaybackSettings.crossfadeDurationKey)
        let s = PlaybackSettings()
        XCTAssertEqual(s.crossfadeDurationSeconds, 12.0, accuracy: 0.0001)
    }

    func test_init_fallsBackToDefault_whenNoStoredValues() {
        // Both keys absent — defaults apply.
        let s = PlaybackSettings()
        XCTAssertEqual(s.crossfadeDurationSeconds, 6.0, accuracy: 0.0001)
        XCTAssertTrue(s.gaplessEnabled)
    }

    // MARK: - Setters + onChange

    func test_setter_persistsCrossfadeToUserDefaults() {
        let s = PlaybackSettings()
        s.crossfadeDurationSeconds = 4.0
        XCTAssertEqual(
            UserDefaults.standard.double(
                forKey: PlaybackSettings.crossfadeDurationKey
            ),
            4.0,
            accuracy: 0.0001
        )
    }

    func test_setter_persistsGaplessToUserDefaults() {
        let s = PlaybackSettings()
        s.gaplessEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(
            forKey: PlaybackSettings.gaplessKey))
    }

    func test_setter_invokesOnChange_oncePerWrite() {
        let s = PlaybackSettings()
        var fired = 0
        s.onChange = { fired += 1 }
        s.crossfadeDurationSeconds = 3.0
        s.gaplessEnabled = false
        XCTAssertEqual(fired, 2)
    }

    func test_updateCrossfade_clampsValueToStep() {
        let s = PlaybackSettings()
        s.updateCrossfade(seconds: 5.7)
        // 5.7 should snap to 5.5 (the nearest 0.5 s step).
        XCTAssertEqual(s.crossfadeDurationSeconds, 5.5, accuracy: 0.0001)
    }
}
