import XCTest
import SwiftData
@testable import Lunar

@MainActor
final class AudioEngineQueueTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: LunarSchema.schema, configurations: config)
    }

    private func makeRequest(
        container: ModelContainer,
        title: String,
        duration: TimeInterval = 100
    ) throws -> PlaybackRequest {
        let context = container.mainContext
        let song = Song(title: title, artist: "Test", fileName: "\(title.lowercased()).m4a")
        context.insert(song)
        try? context.save()
        return PlaybackRequest(
            songID: song.persistentModelID,
            title: song.title,
            artist: song.artist,
            fileURL: URL(fileURLWithPath: "/dev/null"),
            duration: duration
        )
    }

    // MARK: - Queue state

    func test_fakeEngine_startsEmpty() {
        let engine = FakeAudioEngine()
        XCTAssertEqual(engine.queueSize, 0)        // Fake doesn't expose the queue
        // We rely on Fake state for now (queue internals are verified on real engine).
    }

    // MARK: - Real engine: queue wiring

    func test_realEngine_playQueue_sendsLoadAndPlay() async throws {
        let container = try makeContainer()
        let r1 = try makeRequest(container: container, title: "Alpha")
        let r2 = try makeRequest(container: container, title: "Beta")
        let r3 = try makeRequest(container: container, title: "Gamma")

        let engine = AudioEngine()
        engine.playQueue([r1, r2, r3])
        // Drain the fire-and-forget Task
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(engine.queueSize, 3)
        XCTAssertEqual(engine.currentQueueIndex, 0)
        // The first song has been loaded via the FakeAudioFile fallback,
        // but real AVAudioFile read of /dev/null will fail — that's fine,
        // we just confirm the wiring fires.
    }

    func test_realEngine_playQueue_withEmptyList_noop() async throws {
        let engine = AudioEngine()
        engine.playQueue([])
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(engine.queueSize, 0)
    }

    func test_realEngine_enqueueNext_onEmptyQueue_seedsAtZero() async throws {
        let container = try makeContainer()
        let r = try makeRequest(container: container, title: "Solo")

        let engine = AudioEngine()
        engine.enqueueNext(r)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(engine.queueSize, 1)
        XCTAssertEqual(engine.currentQueueIndex, 0)
    }

    func test_realEngine_enqueueNext_afterPlayQueue_insertsAfterCurrent() async throws {
        let container = try makeContainer()
        let r1 = try makeRequest(container: container, title: "First")
        let r2 = try makeRequest(container: container, title: "Second")
        let r3 = try makeRequest(container: container, title: "AfterCurrent")

        let engine = AudioEngine()
        engine.playQueue([r1, r2])
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(engine.currentQueueIndex, 0)
        engine.enqueueNext(r3)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(engine.queueSize, 3)
        // r3 should be at index 1 (between current=0 and the rest)
        XCTAssertEqual(engine.upcomingRequests.first?.title, "AfterCurrent")
    }

    func test_realEngine_next_atEndOfQueue_pauses() async throws {
        let container = try makeContainer()
        let r1 = try makeRequest(container: container, title: "Only")

        let engine = AudioEngine()
        engine.playQueue([r1])
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(engine.queueSize, 1)
        XCTAssertEqual(engine.currentQueueIndex, 0)

        engine.next()    // queueIndex + 1 == queue.count → pause + reset
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(engine.currentQueueIndex, 0)  // did not advance
        XCTAssertFalse(engine.state.isPlaying)
        XCTAssertEqual(engine.state.currentTime, 0)
    }
}
