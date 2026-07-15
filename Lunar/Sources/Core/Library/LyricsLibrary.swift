import Foundation

/// Errors raised by `LyricsLibrary` operations.
enum LyricsLibraryError: LocalizedError {
    case directoryUnavailable(URL?, underlying: Error?)
    case fileNotFound(filename: String)

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable(let url, let underlying):
            let base = "Lyrics directory unavailable"
            if let url { return base + " at \(url.lastPathComponent)" }
            return base + (underlying.map { ": \($0.localizedDescription)" } ?? "")
        case .fileNotFound(let filename):
            return "Lyrics file '\(filename)' is missing from the directory."
        }
    }
}

/// File-system façade for the lyrics sandbox.
///
/// Mirrors `MusicLibrary`'s conventions: relative paths on
/// `Song.lyricsFileName`, sandbox-relocated URLs on upgrade, a
/// test-only `_rootDirectoryOverride` so the test target can redirect
/// the destination to a per-test temp directory.
enum LyricsLibrary {

    /// Root directory for imported lyrics files. Created lazily.
    static var rootDirectory: URL {
        if let override = _rootDirectoryOverride { return override }
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Lyrics", isDirectory: true)
    }

    /// Test-only override for `rootDirectory`. Nil in production.
    /// `nonisolated(unsafe)` mirrors `MusicLibrary._rootDirectoryOverride`
    /// — see that file for the full rationale.
    nonisolated(unsafe) static var _rootDirectoryOverride: URL?

    /// Make sure the root directory exists. Call once on app launch
    /// (cheap if already present).
    @discardableResult
    static func ensureLyricsDirectory() throws -> URL {
        let url = rootDirectory
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw LyricsLibraryError.directoryUnavailable(url, underlying: error)
            }
        }
        return url
    }

    /// Reconstruct the absolute URL for a song's lyrics file.
    /// Returns `nil` when the file is missing on disk (caller treats
    /// as "no lyrics available").
    static func absoluteURL(forFileName fileName: String) -> URL? {
        let url = rootDirectory.appendingPathComponent(fileName, isDirectory: false)
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    /// Same as `absoluteURL(forFileName:)` but throws on missing.
    static func requireURL(forFileName fileName: String) throws -> URL {
        if let url = absoluteURL(forFileName: fileName) { return url }
        throw LyricsLibraryError.fileNotFound(filename: fileName)
    }
}
