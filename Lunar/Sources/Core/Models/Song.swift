import Foundation
import SwiftData

/// A single track in the user's library.
///
/// **Threading rules** (enforced by SwiftData):
///   - `Song` instances are bound to the `ModelContext` that fetched
///     them. **Never** pass a Song to a background queue (e.g. the
///     audio render thread on `AVAudioEngine`).
///   - Pass a `PersistentIdentifier`, a copy of the scalar fields
///     (title, duration), or the resolved `URL` to background code.
///   - Fetch Songs on the `mainContext` for `@Query` views.
///
/// **Sandbox URL rule**:
///   - Persist only the **relative** `fileName`. Apple may rotate the
///     app sandbox directory UUID on update/restore; absolute URLs
///     would silently break. Rebuild absolute paths at read time
///     via `MusicLibrary.absoluteURL(forFileName:)`.
@Model
final class Song {

    var id: UUID

    var title: String

    /// **Denormalized** for fast `@Query` `SortDescriptor(\Song.artist)`
    /// queries. The canonical source is `artistEntity`; this string is
    /// kept in sync on import/edit by the library service.
    var artist: String

    /// **Denormalized** for the same fast-sort concern as `artist`.
    var albumTitle: String?

    var trackNumber: Int?
    var year: Int?
    var duration: TimeInterval

    /// Relative filename inside `Documents/Music/`. Never store an
    /// absolute `URL` here.
    var fileName: String

    var fileSize: Int64
    var format: String?
    var bitrate: Int?
    var sampleRate: Double?
    var bitDepth: Int?

    var dateAdded: Date
    var lastPlayed: Date?
    var playCount: Int

    /// Drives the heart icon **and** the "My Favorites" smart playlist
    /// (rendered as a one-line `@Query(#Predicate { $0.isFavorite == true })`).
    /// Toggling this flag automatically refreshes both.
    var isFavorite: Bool

    /// Stored on-disk by SwiftData via `.externalStorage` so row
    /// fetches don't pull the full image bytes into memory. Critical
    /// for scroll performance on the Library / Playlist list views.
    @Attribute(.externalStorage) var artwork: Data?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify) var album: Album?

    @Relationship(deleteRule: .nullify) var artistEntity: Artist?

    @Relationship(deleteRule: .cascade, inverse: \ListenEvent.song)
    var listenEvents: [ListenEvent] = []

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        albumTitle: String? = nil,
        trackNumber: Int? = nil,
        year: Int? = nil,
        duration: TimeInterval = 0,
        fileName: String,
        fileSize: Int64 = 0,
        format: String? = nil,
        bitrate: Int? = nil,
        sampleRate: Double? = nil,
        bitDepth: Int? = nil,
        dateAdded: Date = Date(),
        artwork: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.trackNumber = trackNumber
        self.year = year
        self.duration = duration
        self.fileName = fileName
        self.fileSize = fileSize
        self.format = format
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.dateAdded = dateAdded
        self.lastPlayed = nil
        self.playCount = 0
        self.isFavorite = false
        self.artwork = artwork
    }
}
