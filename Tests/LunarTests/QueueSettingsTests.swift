import XCTest
import Observation
@testable import Lunar

/// Tests for `QueueSettings` — the user-facing queue preferences
/// (Shuffle + Repeat). Confirms defaults, persistence to UserDefaults,
/// the `cycleRepeatMode` / `toggleShuffleMode` semantics, and the
/// `onChange` callback that mirrors changes into the live `AudioEngine`.
///
/// Lifestyle mirrors `PlaybackSettingsTests` so a future refactor keeps
/// the two symmetric.
@MainActor
final class QueueSettingsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: QueueSettings.shuffleKey)
        UserDefaults.standard.removeObject(forKey: QueueSettings.repeatKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: QueueSettings.shuffleKey)
        UserDefaults.standard.removeObject(forKey: QueueSettings.repeatKey)
        try await super.tearDown()
    }

    // MARK: - Defaults

    func test_init_defaultsAreBothOff() {
        let s = QueueSettings()
        XCTAssertEqual(s.shuffleMode, .off)
        XCTAssertEqual(s.repeatMode, .off)
    }

    func test_supportedConstantsMatchTheBrief() {
        XCTAssertEqual(QueueSettings.defaultShuffle, .off)
        XCTAssertEqual(QueueSettings.defaultRepeat, .off)
    }

    // MARK: - Persistence

    func test_init_restoresStoredShuffleOn() {
        UserDefaults.standard.set(ShuffleMode.on.rawValue, forKey: QueueSettings.shuffleKey)
        let s = QueueSettings()
        XCTAssertEqual(s.shuffleMode, .on)
    }

    func test_init_restoresStoredRepeatAll() {
        UserDefaults.standard.set(RepeatMode.all.rawValue, forKey: QueueSettings.repeatKey)
        let s = QueueSettings()
        XCTAssertEqual(s.repeatMode, .all)
    }

    func test_init_restoresStoredRepeatOne() {
        UserDefaults.standard.set(RepeatMode.one.rawValue, forKey: QueueSettings.repeatKey)
        let s = QueueSettings()
        XCTAssertEqual(s.repeatMode, .one)
    }

    func test_init_fallsBackToDefaults_whenNoStoredValues() {
        let s = QueueSettings()
        XCTAssertEqual(s.shuffleMode, .off)
        XCTAssertEqual(s.repeatMode, .off)
    }

    func test_init_ignoresCorruptRawValue_staysAtDefault() {
        // Raw value that doesn't map to any case — fall back to default
        // rather than crash. (String init failures here would otherwise
        // propagate into `ShuffleMode?.init?` returning nil.)
        UserDefaults.standard.set("invalid-mode", forKey: QueueSettings.shuffleKey)
        let s = QueueSettings()
        XCTAssertEqual(s.shuffleMode, .off)
    }

    // MARK: - Setters + onChange

    func test_setter_persistsShuffleToUserDefaults() {
        let s = QueueSettings()
        s.shuffleMode = .on
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: QueueSettings.shuffleKey),
            ShuffleMode.on.rawValue
        )
    }

    func test_setter_persistsRepeatToUserDefaults() {
        let s = QueueSettings()
        s.repeatMode = .all
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: QueueSettings.repeatKey),
            RepeatMode.all.rawValue
        )
    }

    func test_setter_invokesOnChange_oncePerWrite() {
        let s = QueueSettings()
        var fired = 0
        s.onChange = { fired += 1 }
        s.shuffleMode = .on
        s.repeatMode = .all
        XCTAssertEqual(fired, 2)
    }

    func test_setter_doesNotFire_whenValueIsUnchanged() {
        // Swift does NOT fire `didSet` on assignment if the value
        // didn't change — this test pins that behaviour so we get
        // cheap (no-op) re-mirror calls when consumer code assigns
        // the same value back (e.g. when AudioEngine.writeback loops).
        let s = QueueSettings()
        s.repeatMode = .all
        var fired = 0
        s.onChange = { fired += 1 }
        s.repeatMode = .all
        XCTAssertEqual(fired, 0)
    }

    // MARK: - Toggle / Cycle helpers

    func test_cycleRepeatMode_walksOffAllOneOff() {
        let s = QueueSettings()
        XCTAssertEqual(s.repeatMode, .off)
        s.cycleRepeatMode()
        XCTAssertEqual(s.repeatMode, .all)
        s.cycleRepeatMode()
        XCTAssertEqual(s.repeatMode, .one)
        s.cycleRepeatMode()
        XCTAssertEqual(s.repeatMode, .off)
    }

    func test_toggleShuffleMode_isBinary() {
        let s = QueueSettings()
        XCTAssertEqual(s.shuffleMode, .off)
        s.toggleShuffleMode()
        XCTAssertEqual(s.shuffleMode, .on)
        s.toggleShuffleMode()
        XCTAssertEqual(s.shuffleMode, .off)
    }

    func test_cycleRepeatMode_persistsAfterEveryStep() {
        let s = QueueSettings()
        s.cycleRepeatMode()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: QueueSettings.repeatKey),
            RepeatMode.all.rawValue
        )
        s.cycleRepeatMode()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: QueueSettings.repeatKey),
            RepeatMode.one.rawValue
        )
        s.cycleRepeatMode()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: QueueSettings.repeatKey),
            RepeatMode.off.rawValue
        )
    }
}

/// System image names are part of the public contract because
/// `TransportRow` consumes them. Pin them so a future rename of an
/// SF Symbol doesn't leave the transport row blank.
extension QueueSettingsTests {
    func test_shuffleModeSystemImages_neverEmpty() {
        XCTAssertFalse(ShuffleMode.off.systemImage.isEmpty)
        XCTAssertFalse(ShuffleMode.on.systemImage.isEmpty)
    }

    func test_repeatModeSystemImages_neverEmpty() {
        XCTAssertFalse(RepeatMode.off.systemImage.isEmpty)
        XCTAssertFalse(RepeatMode.all.systemImage.isEmpty)
        XCTAssertFalse(RepeatMode.one.systemImage.isEmpty)
    }

    func test_shuffleModeSystemImages_areDistinct() {
        XCTAssertNotEqual(ShuffleMode.off.systemImage, ShuffleMode.on.systemImage)
    }

    func test_repeatModeSystemImages_areDistinct() {
        XCTAssertNotEqual(RepeatMode.off.systemImage, RepeatMode.all.systemImage)
        XCTAssertNotEqual(RepeatMode.off.systemImage, RepeatMode.one.systemImage)
        XCTAssertNotEqual(RepeatMode.all.systemImage, RepeatMode.one.systemImage)
    }
}
