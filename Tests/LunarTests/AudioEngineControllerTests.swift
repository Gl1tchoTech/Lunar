import XCTest
import SwiftData
import Lunar
@testable import Lunar
import AVFoundation

@MainActor
final class AudioEngineControllerTests: XCTestCase {

    /// Build an in-memory container plus one inserted song so we have
    /// a real `PersistentIdentifier` to pass into `PlaybackRequest`.
    private func makeRequest(
        title: String = "Creep",
        artist: String = "Radiohead",
        duration: TimeInterval = 240,
        fileName: String = "creep.m4a"
    ) throws -> (container: ModelContainer, request: PlaybackRequest) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LunarSchema.schema,
            configurations: config
        )
        let context = container.mainContext
        let song = Song(title: title, artist: artist, fileName: fileName)
        context.insert(song)
        try? context.save()
        let url = URL(fileURLWithPath: "/dev/null")
        let request = PlaybackRequest(
            songID: song.persistentModelID,
            title: title,
            artist: artist,
            fileURL: url,
            duration: duration
        )
        return (container, request)
    }

    func test_fakeEngine_recordsCommands() async throws {
        let engine = FakeAudioEngine()
        await engine.send(.play)
        await engine.send(.pause)
        XCTAssertEqual(engine.sentCommands.count, 2)
    }

    func test_fakeEngine_playTogglesState() async throws {
        let engine = FakeAudioEngine()
        XCTAssertFalse(engine.state.isPlaying)
        await engine.send(.togglePlayPause)
        XCTAssertTrue(engine.state.isPlaying)
        await engine.send(.togglePlayPause)
        XCTAssertFalse(engine.state.isPlaying)
    }

    func test_fakeEngine_loadUpdatesTitleAndDuration() async throws {
        let (_, request) = try makeRequest()
        let engine = FakeAudioEngine()
        await engine.send(.load(request))
        XCTAssertEqual(engine.state.currentTitle, "Creep")
        XCTAssertEqual(engine.state.currentArtist, "Radiohead")
        XCTAssertEqual(engine.state.duration, 240)
        XCTAssertEqual(engine.state.currentTime, 0)
    }

    func test_fakeEngine_setVolumeClampedNoneInFake() async throws {
        // Fake has no clamping behaviour (real AudioEngine clamps too,
        // but the fake trusts the contract); we just verify the round-trip.
        let engine = FakeAudioEngine()
        await engine.send(.setVolume(0.5))
        XCTAssertEqual(engine.state.volume, 0.5, accuracy: 0.0001)
        await engine.send(.seek(42))
        XCTAssertEqual(engine.state.currentTime, 42)
    }

    func test_fakeEngine_tickProgress_stopsAtDuration() async throws {
        let (_, request) = try makeRequest(title: "T", artist: "A", duration: 10)
        let engine = FakeAudioEngine()
        await engine.send(.load(request))
        await engine.send(.play)
        engine.tickProgress(by: 4)
        XCTAssertEqual(engine.state.currentTime, 4, accuracy: 0.001)
        XCTAssertTrue(engine.state.isPlaying)
        engine.tickProgress(by: 8)
        XCTAssertFalse(engine.state.isPlaying)
    }

    func test_fakeEngine_crossfadeUpdateState() async throws {
        let (_, requestA) = try makeRequest(title: "Song A", artist: "X")
        let (_, requestB) = try makeRequest(title: "Song B", artist: "Y")
        let engine = FakeAudioEngine()
        await engine.send(.load(requestA))
        await engine.send(.crossfade(to: requestB, durationSeconds: 4))
        XCTAssertEqual(engine.state.currentTitle, "Song B")
        XCTAssertEqual(engine.state.currentArtist, "Y")
        XCTAssertTrue(engine.state.isPlaying)
    }

    func test_fakeEngine_commandHistoryCapturesAll() async throws {
        let (_, request) = try makeRequest()
        let engine = FakeAudioEngine()
        await engine.send(.load(request))
        await engine.send(.play)
        await engine.send(.seek(30))
        await engine.send(.pause)
        await engine.send(.togglePlayPause)
        XCTAssertEqual(engine.sentCommands.count, 5)
        if case .load = engine.sentCommands[0] {} else { XCTFail("Expected .load at index 0") }
        if case .play = engine.sentCommands[1] {} else { XCTFail("Expected .play at index 1") }
        if case .seek(let t) = engine.sentCommands[2] { XCTAssertEqual(t, 30) } else { XCTFail("Expected .seek(30) at index 2") }
        if case .pause = engine.sentCommands[3] {} else { XCTFail("Expected .pause at index 3") }
        if case .togglePlayPause = engine.sentCommands[4] {} else { XCTFail("Expected .togglePlayPause at index 4") }
    }

    // MARK: - EQController (verifiable without hardware)

    func test_eqController_initialUnitHasTenBandsAndIsBypassed() {
        let unit = EQController.makeUnit()
        XCTAssertEqual(unit.bands.count, 10)
        for (idx, band) in unit.bands.enumerated() {
            XCTAssertEqual(band.frequency, Float(EQController.isoBandCentersHz[idx]), accuracy: 0.5)
            XCTAssertTrue(band.bypass, "Band \(idx) starts bypassed")
            XCTAssertEqual(band.gain, 0)
        }
    }

    func test_eqController_applyClampsGains() {
        let unit = EQController.makeUnit()
        let wild: [Float] = [-99, 99, 0, -12, 12, -13, 13, 5, -5, 9]
        EQController.apply(bands: wild, to: unit)
        XCTAssertEqual(unit.bands[0].gain, -12, accuracy: 0.001)
        XCTAssertEqual(unit.bands[1].gain, 12, accuracy: 0.001)
        XCTAssertEqual(unit.bands[2].gain, 0)
        XCTAssertEqual(unit.bands[3].gain, -12, accuracy: 0.001)
        XCTAssertEqual(unit.bands[4].gain, 12, accuracy: 0.001)
        XCTAssertEqual(unit.bands[5].gain, -12, accuracy: 0.001)
        XCTAssertEqual(unit.bands[6].gain, 12, accuracy: 0.001)
        XCTAssertEqual(unit.bands[7].gain, 5)
        XCTAssertEqual(unit.bands[8].gain, -5)
        XCTAssertEqual(unit.bands[9].gain, 9)
        for band in unit.bands { XCTAssertFalse(band.bypass) }
    }

    func test_eqController_bypassEngagesAllBands() {
        let unit = EQController.makeUnit()
        EQController.apply(bands: Array(repeating: 0, count: 10), to: unit)
        XCTAssertFalse(unit.bands.contains(where: { $0.bypass }))
        EQController.bypass(unit)
        XCTAssertTrue(unit.bands.allSatisfy { $0.bypass })
    }
}
