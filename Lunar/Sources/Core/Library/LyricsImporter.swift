import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Orchestrates importing a lyrics (.lrc) file for a specific Song.
///
/// Pipeline (mirrors `MusicImporter`):
/// 1. `startAccessingSecurityScopedResource()` on the source URL.
/// 2. On a `Task.detached(priority: .userInitiated)`: copy bytes into
///    `LyricsLibrary.rootDirectory` under a UUID-prefixed name.
/// 3. Decode text and run `LyricsParser.parse(_:)` as a sanity check —
///    returns the parsed `LyricLine` array so the view can render
///    immediately rather than re-parsing on first display.
/// 4. Hop to the main actor, dedup-check (a song already has lyrics
///    → overwrite the existing file path), set
///    `song.lyricsFileName = "<uuid>.lrc"`, and `context.save()`.
///
/// **Returns the parsed lines** synchronously (after the awaited
/// copy/parse) so the caller can present the view immediately without
/// a second parse pass.
@MainActor
final class LyricsImporter {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// One-line import. Throws on security-scope failure, copy failure,
    /// or unparseable payload (empty result).
    @discardableResult
    func importLyrics(for song: Song, at url: URL) async throws -> [LyricLine] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        try LyricsLibrary.ensureLyricsDirectory()

        // If this song already had lyrics, delete the old file so we
        // don't leak orphans across re-imports. Capture the old name
        // before we overwrite the song property.
        let orphaned = song.lyricsFileName

        let destinationName = "lyrics-\(UUID().uuidString).lrc"
        let destination = LyricsLibrary.rootDirectory
            .appendingPathComponent(destinationName, isDirectory: false)

        // 1. Copy bytes on a detached task so the main actor stays
        //    responsive on large UTF-8 files.
        let source = url
        let target = destination
        let (data, error): (Data, Error?) = await Task.detached(
            priority: .userInitiated
        ) {
            do {
                let bytes = try Data(contentsOf: source)
                try bytes.write(to: target, options: [.atomic])
                return (bytes, nil)
            } catch {
                return (Data(), error)
            }
        }.value

        if let error {
            throw error
        }

        // 2. Parse on the same main actor — UTF-8 decoding is cheap;
        //    doing it here avoids needing to send `LyricLine[]` (a
        //    value type already Sendable) across actors.
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .isoLatin1)
        else {
            // Even if the text can't be decoded as a string, the file
            // is on disk — clean it up before throwing so we don't leak.
            try? FileManager.default.removeItem(at: target)
            throw LyricsLibraryError.fileNotFound(
                filename: "\(target.lastPathComponent) (undecodable)"
            )
        }
        let parsed = LyricsParser.parse(text)
        guard !parsed.isEmpty else {
            try? FileManager.default.removeItem(at: target)
            // Surface as a distinct error so the view can show a
            // helpful "this file has no timing info" message rather
            // than a generic crash.
            throw LyricsLibraryError.fileNotFound(
                filename: "\(target.lastPathComponent) (no timestamps)"
            )
        }

        // 3. Persist.
        song.lyricsFileName = destinationName
        try? context.save()

        // 4. Clean up the old file if it existed.
        if let orphaned {
            let oldURL = LyricsLibrary.rootDirectory
                .appendingPathComponent(orphaned, isDirectory: false)
            if oldURL.path != target.path {
                try? FileManager.default.removeItem(at: oldURL)
            }
        }

        return parsed
    }

    /// Remove lyrics from a song. Deletes the .lrc file from disk and
    /// clears `lyricsFileName`. Safe to call when the song has no
    /// lyrics (no-op).
    func clearLyrics(for song: Song) {
        guard let name = song.lyricsFileName else { return }
        let url = LyricsLibrary.rootDirectory
            .appendingPathComponent(name, isDirectory: false)
        try? FileManager.default.removeItem(at: url)
        song.lyricsFileName = nil
        try? context.save()
    }
}

// MARK: - UTType helper

extension UTType {
    /// Best-effort UTType for an `.lrc` lyrics file.
    ///
    /// `UTType(filenameExtension: "lrc")` dynamically allocates a
    /// conformant type on iOS, but its conformance to `public.text` is
    /// not always picked up cleanly by `fileImporter`. Pair it with
    /// `plainText` so the picker accepts both `.lrc` and any plain
    /// `.txt` the user may have renamed to a lyrics export.
    static var lrcLyrics: UTType {
        let lrc = UTType(filenameExtension: "lrc") ?? .plainText
        // `supersetOf:` gives us a type that includes both lrc + plainText,
        // which is exactly what the fileImporter needs.
        return lrc.superset(of: .plainText) ?? .plainText
    }
}
