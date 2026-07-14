import Foundation
import SwiftData

/// A user-created (or system) collection of songs.
///
/// **Ordering**: iOS 17 SwiftData does NOT preserve order on a
/// many-to-many `[Song]` relationship. We sort each playlist view's
/// `@Query` with `SortDescriptor(\Song.dateAdded)` for now. Future
/// versions may introduce a `PlaylistEntry` join entity with
/// `position: Int` to support drag-to-reorder.
@Model
final class Playlist {

    var id: UUID
    var title: String
    var dateCreated: Date

    /// Reserved for future system-curated collections. **Favorites
    /// are NOT stored here** — they're rendered via a `@Query`
    /// `#Predicate { $0.isFavorite == true }` on `Song` to avoid
    /// state synchronization with the per-song flag.
    var isSystemPlaylist: Bool

    // MARK: - Relationship (many-to-many)

    var songs: [Song] = []

    init(
        id: UUID = UUID(),
        title: String,
        dateCreated: Date = Date(),
        isSystemPlaylist: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dateCreated = dateCreated
        self.isSystemPlaylist = isSystemPlaylist
    }
}
