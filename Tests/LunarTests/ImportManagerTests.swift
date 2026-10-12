import XCTest
import SwiftData
import Lunar
@testable import Lunar

/// Tests for `ImportManager` — the Tier 6 queue + state holder that
/// routes both `ImportView.fileImporter` and scene-level
/// `.onOpenURL` through the same pipeline.
///
/// **Hermetic runner.** `ImportManager` keeps its heavy lifting in
/// an injected closure (`runner`) so each test can supply a synthetic
/// runner without spinning up a real SwiftData environment. Tests
/// that need real `PersistentIdentifier`s set up a one-shot in-memory
/// `ModelContainer`, insert a `Song`, and hand back its id.
@MainActor
final class ImportManagerTests: XCTestCase {

    // MARK: - Enqueue tests

    func test_enqueue_singleURL_appendsToPending() {
        let m = ImportManager()
        m.enqueue(URL(fileURLWithPath: "/tmp/a.m4a"))
        XCTAssertEqual(m.pendingURLs.count, 1)
        XCTAssertEqual(m.pendingURLs.first?.lastPathComponent, "a.m4a")
    }

    func test_enqueueMany_emptyArray_isNoOp() {
        let m = ImportManager()
        m.enqueueMany([])
        XCTAssertTrue(m.pendingURLs.isEmpty)
    }

    func test_enqueueMany_multipleURLs_appendsAll() {
        let m = ImportManager()
        m.enqueueMany([
            URL(fileURLWithPath: "/tmp/a.m4a"),
            URL(fileURLWithPath: "/tmp/b.mp3"),
        ])
        XCTAssertEqual(m.pendingURLs.count, 2)
    }

    // MARK: - Drain tests

    func test_enqueue_withoutRunner_leavesPendingAlone() async throws {
        let m = ImportManager()
        m.enqueue(URL(fileURLWithPath: "/tmp/a.m4a"))
        // Give the drain task a chance to start. Without a runner
        // configured, it short-circuits immediately.
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(m.pendingURLs.count, 1,
                       "Empty runner means drain no-ops; URLs stay queued")
        XCTAssertFalse(m.isImporting)
    }

    func test_runnerSuccess_setsLastImportIDs_andClearsError() async throws {
        let m = ImportManager()
        let fakeID = try makeFakeSongID(inMemory: true)
        m.runner = { _ in
            ImportResult(inserted: [fakeID], skipped: 0, failed: [])
        }
        m.enqueue(URL(fileURLWithPath: "/tmp/a.m4a"))
        try await waitUntilNotImporting(m)
        XCTAssertEqual(m.lastImportIDs, [fakeID])
        XCTAssertNil(m.importError)
        XCTAssertTrue(m.pendingURLs.isEmpty, "Drain consumes all queued URLs")
    }

    func test_runnerFailure_surfacesImportError() async throws {
        let m = ImportManager()
        m.runner = { _ in
            struct FakeError: LocalizedError {
                var errorDescription: String? { "synthetic fire" }
            }
            throw FakeError()
        }
        m.enqueue(URL(fileURLWithPath: "/tmp/a.m4a"))
        try await waitUntilNotImporting(m)
        XCTAssertEqual(m.importError, "synthetic fire")
        XCTAssertTrue(m.lastImportIDs.isEmpty,
                      "A thrown error leaves lastImportIDs untouched")
    }

    func test_runnerPartialFailure_setsImportError_withNames() async throws {
        let m = ImportManager()
        let bad1 = URL(fileURLWithPath: "/tmp/bad-one.m4a")
        let bad2 = URL(fileURLWithPath: "/tmp/bad-two.m4a")
        m.runner = { urls in
            // Echo the URL list we received so we can assert
            // round-tripping works.
            let failed = urls.map { ($0, "broken") }
            return ImportResult(inserted: [], skipped: 0, failed: failed)
        }
        m.enqueueMany([bad1, bad2])
        try await waitUntilNotImporting(m)
        XCTAssertNotNil(m.importError)
        XCTAssertTrue(m.importError!.contains("2 files failed"))
        XCTAssertTrue(m.importError!.contains("bad-one"))
        XCTAssertTrue(m.importError!.contains("bad-two"))
    }

    func test_drainWhileBusy_isIdempotent() async throws {
        let m = ImportManager()
        let fastSignal = AsyncStream<Void>.makeStream()
        m.runner = { urls in
            // Hold the runner open until the test signals.
            for await _ in fastSignal.stream { break }
            return ImportResult(inserted: [], skipped: 0, failed: [])
        }
        m.enqueue(URL(fileURLWithPath: "/tmp/a.m4a"))
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(m.isImporting, "First drain holds the lock")

        // While busy, additional enqueues pile up but DO NOT start a
        // second concurrent drain.
        m.enqueue(URL(fileURLWithPath: "/tmp/b.m4a"))
        m.enqueue(URL(fileURLWithPath: "/tmp/c.m4a"))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(m.pendingURLs.count, 2,
                       "Pending queue absorbs URLs that arrive mid-drain")

        fastSignal.continuation.yield()
        fastSignal.continuation.finish()
        try await waitUntilNotImporting(m)
        XCTAssertTrue(m.pendingURLs.isEmpty,
                      "After first batch finishes, next drain picks up queued URLs")
    }

    func test_clearError_resetsImportError() async throws {
        let m = ImportManager()
        struct FakeError: LocalizedError {
            var errorDescription: String? { "blew up" }
        }
        m.runner = { _ in throw FakeError() }
        m.enqueue(URL(fileURLWithPath: "/tmp/boom.m4a"))
        try await waitUntilNotImporting(m)
        XCTAssertNotNil(m.importError)
        m.clearError()
        XCTAssertNil(m.importError)
    }

    // MARK: - Helpers

    /// Polls `isImporting` until it returns `false`. Timestamps out
    /// after 1.5 s so a stalled drain fails loudly instead of
    /// hanging the test runner.
    private func waitUntilNotImporting(
        _ manager: ImportManager,
        timeout: TimeInterval = 1.5
    ) async throws {
        let start = Date()
        while manager.isImporting {
            try await Task.sleep(for: .milliseconds(20))
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("ImportManager did not finish within \(timeout)s")
                return
            }
        }
    }

    /// Build a real `PersistentIdentifier` in a one-shot in-memory
    /// `ModelContainer`. `ImportResult.inserted` expects the same
    /// type SwiftData hands back from a real fetch.
    private func makeFakeSongID(inMemory: Bool) throws -> PersistentIdentifier {
        let container = try ModelContainer(
            for: LunarSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
        let ctx = ModelContext(container)
        let song = Song(
            title:       "Fake",
            artist:      "Test",
            albumTitle:  nil,
            trackNumber: nil,
            year:        nil,
            duration:    180,
            fileName:    "fake.m4a",
            fileSize:    1024,
            format:      "MP3",
            bitrate:     nil,
            sampleRate:  nil,
            bitDepth:    nil,
            artwork:     nil
        )
        ctx.insert(song)
        return song.persistentModelID
    }
}
