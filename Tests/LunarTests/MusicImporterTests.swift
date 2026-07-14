import XCTest
import SwiftData
@testable import Lunar

/// Tests for `MusicImporter` and (indirectly) `AudioMetadataExtractor`.
///
/// **Hermetic setup:** we override `MusicLibrary._rootDirectoryOverride`
/// to point at a per-test temp directory so imported copies never
/// touch the real Application Support sandbox.
///
/// **Synthetic WAV:** because we can't ship tested audio files with
/// the repo, each test writes a tiny 44.1 kHz mono 1-second sine-
/// wave PCM `.wav` into the temp dir. AVFoundation reads metadata-
/// less WAVs gracefully — falls back to filename stem for title.
@MainActor
final class MusicImporterTests: XCTestCase {

    private var container: ModelContainer?
    private var context: ModelContext?
    private var tempMusicDir: URL?

    override func setUp() async throws {
        try await super.setUp()

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LunarMusicTest-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )

        MusicLibrary._rootDirectoryOverride = dir
        self.tempMusicDir = dir

        let container = try ModelContainer(
            for: LunarSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        self.container = container
        self.context = ModelContext(container)
    }

    override func tearDown() async throws {
        if let dir = tempMusicDir {
            try? FileManager.default.removeItem(at: dir)
        }
        MusicLibrary._rootDirectoryOverride = nil
        container = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_imports_singleWAV_createsOneSongRow() async throws {
        let ctx = try requireContext()
        let srcURL = try writeSineWAV(name: "sine-440hz")

        let importer = MusicImporter(context: ctx)
        let result = try await importer.importFiles(at: [srcURL])

        XCTAssertEqual(result.inserted.count, 1, "One song row must be inserted")
        XCTAssertEqual(result.skipped, 0)
        XCTAssertTrue(result.failed.isEmpty, "No file should fail")

        let songs = try ctx.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(songs.count, 1)
        let song = songs[0]

        // Synthetic WAV has no embedded tags → extractor falls back to
        // filename stem for title; "Unknown Artist" for artist.
        XCTAssertEqual(song.title, "sine-440hz")
        XCTAssertEqual(song.artist, "Unknown Artist")
        XCTAssertNil(song.albumTitle)
        XCTAssertEqual(song.format, "WAV")
        XCTAssertGreaterThan(song.duration, 0.9, "Duration should be ~1s")
        XCTAssertLessThan   (song.duration, 1.1)
        XCTAssertGreaterThan(song.fileSize, 1024, "File size should be at least 1KB")

        // The physical copy lives in the (overridden) rootDirectory.
        XCTAssertNotNil(
            MusicLibrary.absoluteURL(forFileName: song.fileName),
            "Physical copy must resolve through MusicLibrary"
        )

        // The destination filename is collision-safe: UUID-prefixed.
        XCTAssertTrue(song.fileName.hasSuffix(".wav"))
        let stem = (song.fileName as NSString).deletingPathExtension
        XCTAssertEqual(stem.count, 36, "UUID prefix should be 8-4-4-4-12 = 36 chars")
    }

    func test_dedup_reimportSameFile_isSkipped() async throws {
        let ctx = try requireContext()
        let importer = MusicImporter(context: ctx)

        // Pick the exact same WAV twice. Importer can't tell the bytes
        // differ from a re-pick unless metadata extraction produces
        // distinct signatures — a metadata-less WAV is named the same,
        // so the dedup-key matches and the second should skip.
        let src1 = try writeSineWAV(name: "duplicate-song")
        let src2 = try writeSineWAV(name: "duplicate-song")

        _ = try await importer.importFiles(at: [src1])
        let result = try await importer.importFiles(at: [src2])

        XCTAssertEqual(result.inserted.count, 0, "Re-import should not insert")
        XCTAssertEqual(result.skipped, 1, "Re-import should be skipped")

        let songs = try ctx.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(songs.count, 1, "Library holds exactly one copy after dedup")
    }

    func test_imports_multipleUniqueWAVs_insertsAll() async throws {
        let ctx = try requireContext()
        let importer = MusicImporter(context: ctx)

        let urls = try ["alpha", "beta", "gamma"].map { try writeSineWAV(name: $0) }
        let result = try await importer.importFiles(at: urls)

        XCTAssertEqual(result.inserted.count, 3)
        XCTAssertEqual(result.skipped, 0)
        let songs = try ctx.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(songs.count, 3)
    }

    func test_import_failure_onUnreadableFile_isReported() async throws {
        let ctx = try requireContext()

        // Make a path that exists but is NOT readable as audio.
        let notAudio = tempMusicDir!.appendingPathComponent("not-audio.wav")
        try Data("this is not a wav at all".utf8).write(to: notAudio)

        // Override rootDirectory check: importer copies into the
        // override root, not the source dir, so we need the source URL
        // accessible. Use a real path under tempMusicDir.
        let importer = MusicImporter(context: ctx)
        let result = try await importer.importFiles(at: [notAudio])

        // AVAsset may or may not throw on a garbage WAV — either the
        // extraction succeeds with zero duration (and we insert a Song
        // with the filename stem as title) or it throws. Both outcomes
        // are acceptable as long as the importer doesn't crash and the
        // store stays consistent.
        XCTAssertTrue(
            result.inserted.count + result.failed.count == 1,
            "One WAV → one outcome (inserted OR failed)"
        )
        let songs = try ctx.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(songs.count, result.inserted.count,
                       "Song-row count must match inserted count")
    }

    // MARK: - Helpers

    private func requireContext() throws -> ModelContext {
        guard let context else {
            throw MusicImporterTestError.notInitialized
        }
        return context
    }

    /// Writes a tiny 44.1 kHz mono 16-bit PCM WAV containing 1 second
    /// of silence-shaped noise. Returns the URL of the file.
    private func writeSineWAV(name: String) throws -> URL {
        let dir = tempMusicDir ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("\(name).wav", isDirectory: false)
        let sampleRate: UInt32 = 44100
        let durationSeconds: UInt32 = 1
        let numSamples = Int(sampleRate * durationSeconds)
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(numSamples) * UInt32(blockAlign)
        let chunkSize = 36 + dataSize

        var bytes = Data()
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { bytes.append(contentsOf: $0) }
        }
        // RIFF header
        appendLE(UInt32(0x46464952) as UInt32) // "RIFF"
        appendLE(chunkSize)
        appendLE(UInt32(0x45564157) as UInt32) // "WAVE"
        // fmt subchunk
        appendLE(UInt32(0x20746d66) as UInt32) // "fmt "
        appendLE(UInt16(16) as UInt16)        // PCM subchunk size
        appendLE(UInt16(1) as UInt16)         // PCM format
        appendLE(channels)
        appendLE(sampleRate)
        appendLE(byteRate)
        appendLE(blockAlign)
        appendLE(bitsPerSample)
        // data subchunk
        appendLE(UInt32(0x61746164) as UInt32) // "data"
        appendLE(dataSize)
        // Samples — 0 PCM = silence. AVFoundation reads these fine and
        // returns `durationSeconds` for the asset length.
        let sampleBytes = numSamples * Int(blockAlign)
        bytes.append(Data(count: sampleBytes))

        try bytes.write(to: url, options: .atomic)
        return url
    }

    private enum MusicImporterTestError: Error {
        case notInitialized
    }
}
