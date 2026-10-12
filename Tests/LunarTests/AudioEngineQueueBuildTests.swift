import XCTest
import SwiftData
import Lunar
@testable import Lunar

/// Pure-function tests for `AudioEngine.buildQueue(requests:startIndex:shuffleMode:)`.
///
/// The helper was extracted out of `playQueue(_:startIndex:)` so the
/// shuffle-pinning logic can be exercised without spinning up an
/// `AVAudioEngine` (which requires audio hardware + a real process).
/// Pins the Apple Music shuffle contract: when `shuffleMode == .on`
/// and the queue has ≥ 2 songs, the song resolved by `startIndex`
/// stays pinned to position 0 and the rest is shuffled.
///
/// Uses a single in-memory `ModelContainer` per test method (XCTest
/// reuses the test class instance, so each `test_xxx` invocation gets
/// a fresh container via `setUp()`). Much faster than spinning up a
/// container per individual PlaybackRequest, and Swift `value type`
/// initialisers can't synthesise a `PersistentIdentifier` from scratch —
/// we have to bootstrap one through a real `Song` insert.
@MainActor
final class AudioEngineQueueBuildTests: XCTestCase {

    /// Container for the lifetime of a single test method. Built in
    /// `setUp()`, invalidated in `tearDown()`. Generates ~8 `Song` rows
    /// per test → cheap.
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer(
            for: LunarSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    /// Insert a `Song` in the per-test container and return a
    /// `PlaybackRequest` keyed to its `PersistentIdentifier`. Uses a
    /// UUID-suffixed `fileName` so the same title across tests doesn't
    /// collide on re-insertion (each test instance has a fresh
    /// container anyway, but defensive).
    private func makeRequest(
        title: String,
        artist: String = "A",
        duration: TimeInterval = 100
    ) -> PlaybackRequest {
        let song = Song(
            title: title,
            artist: artist,
            fileName: "\(title)-\(UUID().uuidString).m4a"
        )
        container.mainContext.insert(song)
        try? container.mainContext.save()
        return PlaybackRequest(
            songID: song.persistentModelID,
            title: title,
            artist: artist,
            fileURL: URL(fileURLWithPath: "/dev/null/\(title).m4a"),
            duration: duration
        )
    }

    func test_emptyInput_returnsEmptyQueueAndZeroIndex() {
        let (queue, index) = AudioEngine.buildQueue(
            requests: [],
            startIndex: 0,
            shuffleMode: .on
        )
        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(index, 0)
    }

    func test_shuffleOff_preservesInsertionOrder() {
        let requests = (0..<5).map { makeRequest(title: "Song \($0)") }
        let (queue, index) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: 0,
            shuffleMode: .off
        )
        XCTAssertEqual(queue.map(\.title), requests.map(\.title))
        XCTAssertEqual(index, 0)
    }

    func test_shuffleOff_honorsStartIndex() {
        let requests = (0..<5).map { makeRequest(title: "Song \($0)") }
        let (queue, index) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: 3,
            shuffleMode: .off
        )
        XCTAssertEqual(queue.map(\.title), requests.map(\.title))
        XCTAssertEqual(index, 3)
    }

    func test_shuffleOn_pinsStartIndexSongAtPositionZero() {
        let requests = (0..<5).map { makeRequest(title: "Song \($0)") }
        let (queue, index) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: 3,
            shuffleMode: .on
        )
        XCTAssertEqual(queue.count, 5)
        XCTAssertEqual(queue[0].title, "Song 3", "startIndex song must pin to position 0")
        XCTAssertEqual(index, 0)
        let remaining = queue.dropFirst().map(\.title)
        XCTAssertTrue(remaining.contains("Song 0"))
        XCTAssertTrue(remaining.contains("Song 1"))
        XCTAssertTrue(remaining.contains("Song 2"))
        XCTAssertTrue(remaining.contains("Song 4"))
        XCTAssertFalse(remaining.contains("Song 3"))
    }

    func test_shuffleOn_singleSongQueue_fallsBackToInsertionOrder() {
        let requests = [makeRequest(title: "Lonely")]
        let (queue, index) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: 0,
            shuffleMode: .on
        )
        XCTAssertEqual(queue.map(\.title), ["Lonely"])
        XCTAssertEqual(index, 0)
    }

    func test_shuffleOn_startIndexAboveCount_clampsToLast() {
        let requests = (0..<3).map { makeRequest(title: "Song \($0)") }
        let (queue, index) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: 99,
            shuffleMode: .off
        )
        // Even with shuffle off the clamp protects us from OOB; last
        // song == "Song 2" → index 2.
        XCTAssertEqual(queue.map(\.title), ["Song 0", "Song 1", "Song 2"])
        XCTAssertEqual(index, 2)
    }

    func test_shuffleOn_negativeStartIndex_clampsToZero() {
        let requests = (0..<3).map { makeRequest(title: "Song \($0)") }
        let (queue, index) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: -7,
            shuffleMode: .off
        )
        XCTAssertEqual(queue.map(\.title), ["Song 0", "Song 1", "Song 2"])
        XCTAssertEqual(index, 0)
    }

    func test_shuffleOn_pinnedSongAppearsExactlyOnce() {
        let requests = (0..<8).map { makeRequest(title: "Song \($0)") }
        let (queue, _) = AudioEngine.buildQueue(
            requests: requests,
            startIndex: 4,
            shuffleMode: .on
        )
        let counts = Dictionary(grouping: queue, by: \.title).mapValues(\.count)
        for (title, count) in counts {
            XCTAssertEqual(count, 1, "Song \(title) appeared \(count) times — should be exactly 1")
        }
    }
}
