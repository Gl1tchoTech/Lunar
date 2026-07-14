import Foundation

/// Errors raised by `MusicLibrary` operations.
enum MusicLibraryError: LocalizedError {
    case directoryUnavailable(URL?, underlying: Error?)
    case fileNotFound(filename: String)

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable(let url, let underlying):
            let base = "Library directory unavailable"
            if let url { return base + " at \(url.lastPathComponent)" }
            return base + (underlying.map { ": \($0.localizedDescription)" } ?? "")
        case .fileNotFound(let filename):
            return "Music file '\(filename)' is missing from the library directory."
        }
    }
}

/// File-system façade for the music sandbox.
///
/// ## Why this exists
/// `Song.fileName` is **relative** (e.g. `"track-001.m4a"`). iOS rotates
/// the sandbox UUID on every app update / restore, so absolute URLs
/// persist across launches would silently break. We resolve at read
/// time and never let raw URLs leak into the data model.
///
/// ## Why `Application Support/Music/` (not `Documents/`)
/// - `Application Support/` is **not** exposed to the user via Files.app,
///   keeping your library private.
/// - `Documents/` would otherwise invite iCloud backup of raw audio.
enum MusicLibrary {

    /// Root directory for imported audio files. Created lazily.
    static var rootDirectory: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Music", isDirectory: true)
    }

    /// Make sure the root directory exists. Call once on app launch.
    @discardableResult
    static func ensureLibraryDirectory() throws -> URL {
        let url = rootDirectory
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw MusicLibraryError.directoryUnavailable(url, underlying: error)
            }
        }
        return url
    }

    /// Reconstruct the absolute URL for a song's file. Returns `nil`
    /// when the file is missing on disk (caller should treat as stale).
    static func absoluteURL(forFileName fileName: String) -> URL? {
        let url = rootDirectory.appendingPathComponent(fileName, isDirectory: false)
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    /// Same as `absoluteURL(forFileName:)` but throws on missing.
    static func requireURL(forFileName fileName: String) throws -> URL {
        if let url = absoluteURL(forFileName: fileName) { return url }
        throw MusicLibraryError.fileNotFound(filename: fileName)
    }

    /// Free byte counter for diagnostics / Settings UI.
    static var freeDiskSpace: Int64? {
        let url = rootDirectory
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
