import Foundation
import SwiftData

/// A grouping of songs. Albums are derived from the user's library
/// (one Album per unique `(title, artist)` pair).
@Model
final class Album {

    var id: UUID
    var title: String

    /// **Denormalized** for fast album list rendering — same rationale
    /// as `Song.artist`.
    var artist: String

    var year: Int?

    @Attribute(.externalStorage) var artwork: Data?

    // MARK: - Relationship (inverse declared once, here on the to-many side)

    /// `.nullify` keeps songs intact when their album is deleted: their
    /// `album` reference becomes nil but they stay in the library with
    /// their denormalized `albumTitle`.
    @Relationship(deleteRule: .nullify, inverse: \Song.album)
    var songs: [Song] = []

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        year: Int? = nil,
        artwork: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artwork = artwork
    }
}
