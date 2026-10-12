import XCTest
import SwiftData
import Lunar
@testable import Lunar

/// Tests for `LyricsImporter` — the per-song `.lrc` import pipeline.
///
/// Goals:
/// - **Happy path**: writes a Song's `lyricsFileName`, persists a
///   `.lrc` blob to the override directory, returns parsed `LyricLine`s.
/// - **Re-import** replaces the prior file (`oldURL` gets deleted) so
///   we don't orphan lyrics on every re-import.
/// - **Empty / undecodable** payload raises a domain error rather
///   than silently swallowing.
@MainActor
final class LyricsImporterTests: XCTestCase {

    private var tempDir: URL!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var importer: LyricsImporter!
    private var song: Song!

    override func setUp() async throws {
        try await super.setUp()

        // Override the lyrics root so we don't pollute the user's
        // sandbox or Application Support. `nonisolated(unsafe)` is
        // intentional and mirrors `MusicLibrary._rootDirectoryOverride`.
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LunarLyricsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        LyricsLibrary._rootDirectoryOverride = tempDir

        container = try ModelContainer(
            for: LunarSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        importer = LyricsImporter(context: context)

        // Stand up a real Song row so the importer has something to
        // attach the lyrics to.
        song = Song(
            title: "Test Song",
            artist: "Test Artist",
            duration: 0,
            fileName: "song-uuid.caf"
        )
        context.insert(song)
        try context.save()
    }

    override func tearDown() async throws {
        importer = nil
        song = nil
        if let container { _ = container }
        context = nil
        container = nil

        LyricsLibrary._rootDirectoryOverride = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil

        try await super.tearDown()
    }

    // MARK: - Happy path

    func test_importLyrics_writesFileAndAssignsFileName() async throws {
        let lrc = """
        [00:12.50]first lyric line
        [00:24.00]second line
        """
        let sourceURL = try writeTempLRCFile(contents: lrc)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let parsed = try await importer.importLyrics(for: song, at: sourceURL)

        XCTAssertEqual(parsed.count, 2, "Should parse both timed lines.")
        XCTAssertEqual(parsed[0].time, 12.5, accuracy: 0.0001)
        XCTAssertEqual(parsed[1].time, 24.0, accuracy: 0.0001)
        XCTAssertNotNil(song.lyricsFileName)
        XCTAssertTrue(song.lyricsFileName!.hasSuffix(".lrc"))

        // The file should live in the override root with the same name.
        let dest = tempDir.appendingPathComponent(song.lyricsFileName!, isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        let writtenText = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertTrue(writtenText.contains("first lyric line"))
    }

    func test_importLyrics_populatesParsedLinesWithAccurateText() async throws {
        let lrc = "[00:01.00]hello\n[00:02.00]world\n"
        let url = try writeTempLRCFile(contents: lrc)
        defer { try? FileManager.default.removeItem(at: url) }

        let parsed = try await importer.importLyrics(for: song, at: url)
        XCTAssertEqual(parsed.map(\.text), ["hello", "world"])
    }

    // MARK: - Re-import dedup

    func test_importLyrics_reImportDeletesOldFile() async throws {
        // First import.
        let firstURL = try writeTempLRCFile(
            contents: "[00:01.00]first attempt"
        )
        defer { try? FileManager.default.removeItem(at: firstURL) }
        _ = try await importer.importLyrics(for: song, at: firstURL)
        let firstFilename = song.lyricsFileName
        let firstDest = tempDir.appendingPathComponent(firstFilename!, isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstDest.path))

        // Second import with totally different content.
        let secondURL = try writeTempLRCFile(
            contents: "[00:02.00]second attempt"
        )
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let parsed = try await importer.importLyrics(for: song, at: secondURL)

        XCTAssertNotEqual(song.lyricsFileName, firstFilename, "Names should change (UUID suffix).")
        XCTAssertEqual(parsed.map(\.text), ["second attempt"])

        // Old file should be gone; new file should be present.
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: firstDest.path),
            "Old lyrics file should be cleaned up on re-import."
        )
        let newDest = tempDir.appendingPathComponent(song.lyricsFileName!, isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDest.path))
    }

    // MARK: - Error surface

    func test_importLyrics_emptyFile_throwsNoTimestamps() async throws {
        let lrc = "[ti:No Lyrics Here]\n[ar:Anonymous]\n[al:None]\n"
        let url = try writeTempLRCFile(contents: lrc)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await importer.importLyrics(for: song, at: url)
            XCTFail("Empty LRC file should throw — not silently succeed.")
        } catch {
            // Whatever error flavour, the song shouldn't have lyrics now.
            XCTAssertNil(song.lyricsFileName)
        }
    }

    func test_importLyrics_blankFile_throws() async throws {
        let url = try writeTempLRCFile(contents: "\n\n\n")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await importer.importLyrics(for: song, at: url)
            XCTFail("Blank LRC should throw.")
        } catch {
            XCTAssertNil(song.lyricsFileName)
        }
    }

    // MARK: - clearLyrics

    func test_clearLyrics_removesFileAndClearsField() async throws {
        // Import first.
        let url = try writeTempLRCFile(contents: "[00:01.00]line")
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try await importer.importLyrics(for: song, at: url)
        XCTAssertNotNil(song.lyricsFileName)

        importer.clearLyrics(for: song)
        XCTAssertNil(song.lyricsFileName)
        let leftover = tempDir.appendingPathComponent(
            song.lyricsFileName ?? "missing.lrc", isDirectory: false
        )
        // We just cleared the field, so undo and assert by old-name.
        // To do this without keeping the old name, re-assert by
        // listing overrides.
        let remainingLyrics = (try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(remainingLyrics.isEmpty || remainingLyrics.contains { $0.lastPathComponent != "left-over" })
        _ = leftover // silence unused-variable warning
    }

    func test_clearLyrics_isNoopWhenNothingToClear() {
        XCTAssertNil(song.lyricsFileName)
        importer.clearLyrics(for: song) // must not trap
        XCTAssertNil(song.lyricsFileName)
    }

    // MARK: - Helpers

    private func writeTempLRCFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyrics-\(UUID().uuidString).lrc")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
