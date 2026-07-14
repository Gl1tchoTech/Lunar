import Foundation
import SwiftData

/// A performer / band credited on one or more songs.
@Model
final class Artist {

    var id: UUID
    var name: String
    var bio: String?

    @Attribute(.externalStorage) var artwork: Data?

    // MARK: - Relationship (inverse declared once, here on the to-many side)

    /// `.nullify` keeps songs intact when the artist entry is removed.
    @Relationship(deleteRule: .nullify, inverse: \Song.artistEntity)
    var songs: [Song] = []

    init(
        id: UUID = UUID(),
        name: String,
        bio: String? = nil,
        artwork: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.bio = bio
        self.artwork = artwork
    }
}
