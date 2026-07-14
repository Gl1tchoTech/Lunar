import Foundation
import SwiftData

/// One "play" of a song. Written every time a song completes or is
/// skipped past ~10 seconds. Used by the smart playlists:
/// - **Most Played** — `count(ListenEvent) desc per song`
/// - **Recently Played** — `distinct(song) by max(ListenEvent.timestamp)`
///
/// `.cascade` on `Song.delete` cleans these up so we don't leak
/// dangling events.
@Model
final class ListenEvent {

    var id: UUID
    var timestamp: Date
    /// How long the user actually listened — NOT how long the song is.
    var playedDuration: TimeInterval
    var completed: Bool   // true if the song played to end without skipping

    // MARK: - Relationship (inverse declared on Song side via Song.listenEvents)

    var song: Song?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        playedDuration: TimeInterval = 0,
        completed: Bool = false,
        song: Song? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.playedDuration = playedDuration
        self.completed = completed
        self.song = song
    }
}
