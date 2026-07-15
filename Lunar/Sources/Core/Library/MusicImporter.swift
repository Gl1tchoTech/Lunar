import Foundation
import SwiftData

/// Result of an `MusicImporter.importFiles(at:)` run.
struct ImportResult: Equatable, Sendable {
    /// Newly persisted `Song` rows in the order they were imported.
    let inserted: [PersistentIdentifier]
    /// Number of files that were skipped because they matched an
    /// existing song in the library.
    let skipped: Int
    /// Files that failed to copy or extract. Each entry carries the
    /// original (not-yet-imported) source URL plus the error.
    let failed: [(url: URL, message: String)]

    /// Manual `==` because arrays of `(URL, String)` tuples don't
    /// synthesize `Equatable`. We compare count + element-wise first so
    /// a single mismatch short-circuits as `false`.
    static func == (lhs: ImportResult, rhs: ImportResult) -> Bool {
        guard lhs.inserted == rhs.inserted, lhs.skipped == rhs.skipped else { return false }
        guard lhs.failed.count == rhs.failed.count else { return false }
        for (l, r) in zip(lhs.failed, rhs.failed) {
            if l.url != r.url || l.message != r.message { return false }
        }
        return true
    }
}

/// @MainActor orchestrator for Tier 1 — "Import → Local Files".
///
/// **Pipeline:**
/// - For each picked URL we (a) copy it into `MusicLibrary.rootDirectory`
///   with a collision-safe UUID-prefixed name on a detached Task, then
///   (b) run `AudioMetadataExtractor.extract` (also detached), and
///   finally (c) hop back to the main actor to dedup-check + insert.
/// - All SwiftData mutations happen on this method's actor; the
///   detached Tasks only touch the file system and produce a
///   Sendable payload.
///
/// **Why precompute dedup + Artist/Album caches at the start?**
/// Fetching these after each insert would force SwiftData to flush
/// the in-memory context on each loop iteration. Doing it once means
/// the whole batch is one save() — and the SwiftData row-write rate
/// stays predictable on a 200-song library import.
///
/// **Why `@MainActor` on the class but `Task.detached` internally?**
/// Plain SwiftUI work (`.task` modifiers, button actions) runs on the
/// main actor. The class being `@MainActor` lets the View call it
/// directly without bridging. The I/O work is structurally below us
/// on a detached task so the engine rotates progress UI freely.
@MainActor
final class MusicImporter {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Public entry-point. Safe to call from a SwiftUI `.task` or a
    /// button action. Calls `MusicLibrary.ensureLibraryDirectory()`
    /// first so the first import doesn't have to do it.
    @discardableResult
    func importFiles(at urls: [URL]) async throws -> ImportResult {

        // Ensure the destination directory exists up-front so the
        // detached copies never race on directory creation.
        try MusicLibrary.ensureLibraryDirectory()

        // Prefetch dedup set + Artist / Album caches in one round
        // trip. Cheap even on a 200-song library.
        var dedupKeys  = readExistingDedupKeys()
        var artistCache = readArtistCache()
        var albumCache  = readAlbumCache()

        var insertedIDs: [PersistentIdentifier] = []
        var failed: [(URL, String)] = []
        var skipped = 0

        for sourceURL in urls {
            do {
                let payload = try await copyAndExtract(from: sourceURL)

                let key = dedupKey(for: payload)
                if dedupKeys.contains(key) {
                    // Duplicate — remove the orphan copy we just made.
                    try? FileManager.default.removeItem(at: payload.importedFileURL)
                    skipped += 1
                    continue
                }

                let song = try insert(
                    payload: payload,
                    artistCache: &artistCache,
                    albumCache: &albumCache
                )

                insertedIDs.append(song.persistentModelID)
                dedupKeys.insert(key)
            } catch {
                failed.append((sourceURL, error.localizedDescription))
            }
        }

        // Single save flushes the whole batch.
        try? context.save()

        return ImportResult(
            inserted: insertedIDs,
            skipped:  skipped,
            failed:   failed
        )
    }

    // MARK: - Per-file stages

    /// Copy + extract a single URL. Returns a Sendable payload that
    /// only references the imported copy's *absolute* URL.
    ///
    /// Security scope: `fileImporter` URLs may belong to iCloud Drive
    /// or a Files-provider app, both of which require explicit
    /// `startAccessingSecurityScopedResource()`. We call symmetric
    /// `start` / `stop` (only stop if `start` returned `true`) inside
    /// a `defer` so dangling scopes can't accumulate.
    private func copyAndExtract(from sourceURL: URL) async throws -> ImportedTrackPayload {

        let didStartScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartScope { sourceURL.stopAccessingSecurityScopedResource() }
        }

        // Collision-safe destination name. We keep the original
        // extension so iOS pattern-matchers (`audio/*`) still work.
        let ext = sourceURL.pathExtension
        let safeExt = ext.isEmpty ? "audio" : ext
        let safeName = "\(UUID().uuidString).\(safeExt)"
        let destination = MusicLibrary.rootDirectory
            .appendingPathComponent(safeName, isDirectory: false)

        // Copy on a detached task so multi-MB FLACs don't stall the UI.
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        }.value

        // Extract metadata. If the file is unreadable (DRM, etc.) we
        // surface the error so the caller can record a failure
        // instead of inserting a Song with `duration=0` and `title=?`.
        return try await AudioMetadataExtractor.extract(from: destination)
    }

    /// Insert one Song + (possibly new) Artist + Album on the main
    /// actor. Returns the inserted Song so the caller can collect
    /// IDs for the result. Caller already dedup-checked.
    private func insert(
        payload: ImportedTrackPayload,
        artistCache: inout [String: Artist],
        albumCache: inout [String: Album]
    ) throws -> Song {

        let normalizedArtist = payload.artist.trimmedNonEmpty ?? "Unknown Artist"
        let artistKey = normalizedArtist.lowercased()

        // Find-or-create artist.
        let artist: Artist
        if let cached = artistCache[artistKey] {
            artist = cached
        } else {
            let fresh = Artist(name: normalizedArtist)
            context.insert(fresh)
            artistCache[artistKey] = fresh
            artist = fresh
        }
        // First-track-wins for artist artwork (if the artist didn't
        // already have one in the store, borrow from this song).
        if artist.artwork == nil, let art = payload.artwork {
            artist.artwork = art
        }

        let song = Song(
            title:       payload.title,
            artist:      normalizedArtist,
            albumTitle:  payload.albumTitle,
            trackNumber: payload.trackNumber,
            year:        payload.year,
            duration:    payload.duration,
            fileName:    payload.importedFileURL.lastPathComponent,
            fileSize:    payload.fileSize,
            format:      payload.format,
            bitrate:     payload.bitrate,
            sampleRate:  payload.sampleRate,
            bitDepth:    payload.bitDepth,
            artwork:     payload.artwork
        )

        song.artistEntity = artist

        // Find-or-create album.
        if let albumTitle = payload.albumTitle?.trimmedNonEmpty {
            let albumKey = "\(artistKey)|\(albumTitle.lowercased())"
            let album: Album
            if let cached = albumCache[albumKey] {
                album = cached
            } else {
                let fresh = Album(
                    title:  albumTitle,
                    artist: normalizedArtist
                )
                context.insert(fresh)
                albumCache[albumKey] = fresh
                album = fresh
            }
            if album.artwork == nil, let art = payload.artwork {
                album.artwork = art
            }
            song.album = album
        }

        context.insert(song)
        return song
    }

    // MARK: - Prefetch helpers

    /// Build the dedup set covering the entire existing library in
    /// one pass. Imported today will be checked against this; new
    /// entries are added in `importFiles` so back-to-back imports in
    /// the same run also dedup against each other.
    private func readExistingDedupKeys() -> Set<String> {
        let descriptor = FetchDescriptor<Song>()
        let existing = (try? context.fetch(descriptor)) ?? []
        return Set(existing.map { song in
            Self.makeDedupKey(
                title:      song.title,
                artist:     song.artist,
                albumTitle: song.albumTitle,
                duration:   song.duration,
                fallbackOriginalFilename: song.fileName,
                fallbackFileSize:         song.fileSize
            )
        })
    }

    /// Existing artists keyed by `name.lowercased()`. Empty string
    /// normally isn't present in the library (we always substitute
    /// "Unknown Artist") so the cache map is safe.
    private func readArtistCache() -> [String: Artist] {
        let descriptor = FetchDescriptor<Artist>()
        let all = (try? context.fetch(descriptor)) ?? []
        var cache: [String: Artist] = [:]
        for artist in all {
            cache[artist.name.lowercased()] = artist
        }
        return cache
    }

    /// Existing albums keyed by `"\(artist.lowercased())|\(title.lowercased())"`.
    /// The artist prefix prevents "Album X" by Artist A and "Album X"
    /// by Artist B from collapsing into one row.
    private func readAlbumCache() -> [String: Album] {
        let descriptor = FetchDescriptor<Album>()
        let all = (try? context.fetch(descriptor)) ?? []
        var cache: [String: Album] = [:]
        for album in all {
            let key = "\(album.artist.lowercased())|\(album.title.lowercased())"
            cache[key] = album
        }
        return cache
    }

    // MARK: - Dedup key

    /// Compute the dedup key for a payload.
    ///
    /// Two layers of dedup:
    /// 1. **Metadata-based** (`title`, `artist`, `album`, duration
    ///    rounded to the nearest second) — works for tagged files.
    /// 2. **Fallback** (`originalFilename`, `fileSize`) — used when
    ///    metadata extraction returned nothing parseable (raw `.wav`
    ///    with no ID3).
    ///
    /// For each payload we pick one key. Re-importing a tagged MP3
    /// twice hits the metadata-bucket so "song.mp3" (with one set of
    /// tags) dedups, but the same song sourced from a `.flac` rip
    /// (same metadata, different file) also dedups because the
    /// metadata key matches.
    private func dedupKey(for payload: ImportedTrackPayload) -> String {
        Self.makeDedupKey(
            title:      payload.title,
            artist:     payload.artist,
            albumTitle: payload.albumTitle,
            duration:   payload.duration,
            fallbackOriginalFilename: payload.originalFilename,
            fallbackFileSize:         payload.fileSize
        )
    }

    private static func makeDedupKey(
        title: String,
        artist: String,
        albumTitle: String?,
        duration: TimeInterval,
        fallbackOriginalFilename: String,
        fallbackFileSize: Int64
    ) -> String {
        let round = Int(duration.rounded())

        // If metadata extraction truly failed, the artwork-less
        // fallback is the only signal we have.
        let titleIsFilenameStem = title.isEmpty
            || title == (fallbackOriginalFilename as NSString).deletingPathExtension
        let artistIsUnknown = artist.isEmpty || artist == "Unknown Artist"

        if titleIsFilenameStem || artistIsUnknown {
            let stem = (fallbackOriginalFilename.lowercased() as NSString).deletingPathExtension
            return "file|\(stem)|\(fallbackFileSize)"
        }
        return "meta|\(title.lowercased())|\(artist.lowercased())|\((albumTitle ?? "—").lowercased())|\(round)"
    }
}

// MARK: - String convenience (file-local)

private extension String {
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// First run of digits in the receiver, parsed as `Int`. Returns
    /// `nil` when there is no digit.
    var intValue: Int? {
        var digits = ""
        for char in self where char.isNumber { digits.append(char) }
        return digits.isEmpty ? nil : Int(digits)
    }
}
