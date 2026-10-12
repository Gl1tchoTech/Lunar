import XCTest
import Observation
import Lunar
@testable import Lunar

/// Tests for `EQSettings` — the user-facing equalizer state.
///
/// What we pin:
/// - **Defaults**: 10 bands all at 0, master enabled, no preset ID
/// - **`bandBinding(at:)` round-trips**: writes through reassign fire
///   `didSet` (so `currentPresetID` becomes `nil` once user diverges)
/// - **`apply(preset:)`** writes the preset's bands + tags the
///   `currentPresetID` for the highlighted chip
/// - **`reset()`** zeros bands but leaves `isEnabled` alone
/// - **`bands` reshape protection**: if the array ever changes length
///   the property reassigns a fresh zero array of the right size
@MainActor
final class EQSettingsTests: XCTestCase {

    private var settings: EQSettings!

    override func setUp() async throws {
        try await super.setUp()
        settings = EQSettings()
    }

    override func tearDown() async throws {
        settings = nil
        try await super.tearDown()
    }

    // MARK: - Defaults

    func test_init_hasTenBandsAllZero() {
        XCTAssertEqual(settings.bands.count, 10)
        XCTAssertTrue(settings.bands.allSatisfy { $0 == 0 })
    }

    func test_init_isEnabledByDefault() {
        XCTAssertTrue(settings.isEnabled)
    }

    func test_init_hasNoPresetID() {
        XCTAssertNil(settings.currentPresetID)
    }

    func test_constants_matchIsoAndHalfStep() {
        XCTAssertEqual(EQSettings.bandRange.lowerBound, -12.0)
        XCTAssertEqual(EQSettings.bandRange.upperBound, 12.0)
        XCTAssertEqual(EQSettings.bandStep, 0.5)
        XCTAssertEqual(EQController.isoBandCentersHz.count, 10)
    }

    // MARK: - bandBinding round-trip

    func test_bandBinding_setUpdatesBoundArray() {
        let binding = settings.bandBinding(at: 0)
        binding.wrappedValue = -3.5
        XCTAssertEqual(settings.bands[0], -3.5)
    }

    func test_bandBinding_setOutOfRangeBoolIsNoop() {
        let binding = settings.bandBinding(at: 99)
        binding.wrappedValue = 5.0
        // Good index should remain untouched.
        XCTAssertEqual(settings.bands[0], 0)
    }

    func test_bandBinding_getReturnsZeroForBadIndex() {
        XCTAssertEqual(settings.bandBinding(at: 99).wrappedValue, 0)
    }

    func test_writingBand_clearsCurrentPresetID() {
        // Pretend the user picked a preset.
        let preset = makeFakePreset(name: "Flat", bands: Array(repeating: 0, count: 10))
        settings.apply(preset: preset)
        XCTAssertNotNil(settings.currentPresetID)

        // User nudges one band → custom state.
        settings.bandBinding(at: 2).wrappedValue = 4.5
        XCTAssertNil(settings.currentPresetID)
    }

    // MARK: - apply(preset:)

    func test_applyPreset_overwritesBandsAndSetsPresetID() {
        let bands: [Float] = [3, 1.5, -2, 0, 4, -6, 0, 1, -3.5, 8]
        let preset = makeFakePreset(name: "Bass Boost", bands: bands)
        settings.apply(preset: preset)
        XCTAssertEqual(settings.bands, bands)
        XCTAssertEqual(settings.currentPresetID, preset.persistentModelID)
    }

    func test_applyPreset_padsShortBandsWithZeros() {
        let short: [Float] = [1, 2, 3]
        let preset = makeFakePreset(name: "Short", bands: short)
        settings.apply(preset: preset)
        XCTAssertEqual(settings.bands.count, 10)
        XCTAssertEqual(settings.bands.prefix(3), [1, 2, 3])
        XCTAssertEqual(settings.bands.suffix(7), Array(repeating: 0, count: 7))
    }

    func test_applyPreset_trimsLongBandsToTen() {
        let long: [Float] = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 99, 99]
        let preset = makeFakePreset(name: "Long", bands: long)
        settings.apply(preset: preset)
        XCTAssertEqual(settings.bands.count, 10)
        XCTAssertEqual(settings.bands, Array(repeating: 1, count: 10))
    }

    // MARK: - reset()

    func test_reset_zeroesBandsButKeepsEnabledTrue() {
        let preset = makeFakePreset(name: "Big Bass", bands: Array(repeating: 6, count: 10))
        settings.apply(preset: preset)
        XCTAssertTrue(settings.bands.contains { $0 != 0 })

        settings.reset()
        XCTAssertTrue(settings.bands.allSatisfy { $0 == 0 })
        XCTAssertTrue(settings.isEnabled, "Reset must not flip the master toggle.")
    }

    func test_reset_clearsCurrentPresetID() {
        let preset = makeFakePreset(name: "X", bands: Array(repeating: 1, count: 10))
        settings.apply(preset: preset)
        XCTAssertNotNil(settings.currentPresetID)
        settings.reset()
        XCTAssertNil(settings.currentPresetID)
    }

    // MARK: - Reshape protection

    func test_bandsLengthChange_resetsToFlatArray() {
        // Simulate a future migration that drops a band.
        // We can't reassign from outside (it's `var` so we can, but
        // that's what `didSet` would guard against anyway).
        settings.bands = Array(repeating: 0, count: 3)
        XCTAssertEqual(settings.bands.count, 10, "didSet must restore to 10 bands.")
    }

    // MARK: - Helpers (no SwiftData container needed)

    /// Minimal stub that satisfies `EQPreset`'s constructor for tests
    /// that only use `name` + `bands` + `persistentModelID`. We don't
    /// need SwiftData here because `EQSettings.apply(preset:)` reads
    /// only `bands` + `persistentModelID` — never the SwiftData
    /// context.
    private func makeFakePreset(
        name: String,
        bands: [Float]
    ) -> EQPreset {
        // EQPreset is a SwiftData @Model — instantiating it standalone
        // (without a ModelContext) is allowed but `persistentModelID`
        // will be a transient placeholder. That placeholder is
        // unique-per-instance, which is all `EQSettings.apply` needs
        // for equality comparison.
        EQPreset(name: name, isBuiltIn: true, bands: bands)
    }
}
