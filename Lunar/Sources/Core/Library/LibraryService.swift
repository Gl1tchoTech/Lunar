import Foundation
import SwiftData

/// View-layer façade for SwiftData mutations.
///
/// Views call into `LibraryService` instead of poking `context.save()`
/// directly. Centralizing mutations here:
/// - guarantees `context.save()` is never forgotten
/// - keeps `Song.isFavorite` and the auto-derived "My Favorites" smart
///   playlist in lock-step (single source of truth on `Song.isFavorite`)
/// - makes logListenEvent write-side coherent with the audio engine's
///   callback path
///
/// **All public methods are `@MainActor`** — they only run on the main
/// `ModelContext`. Never pass a `Song` to a background queue from
/// inside these methods.
@MainActor
final class LibraryService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: — Favorites

    /// Toggle `Song.isFavorite` and persist. The "My Favorites" smart
    /// playlist is rendered from this exact flag — no separate Playlist
    /// entity to keep in sync.
    @discardableResult
    func toggleFavorite(_ song: Song) -> Bool {
        song.isFavorite.toggle()
        try? context.save()
        return song.isFavorite
    }

    // MARK: — Playlists

    /// Create an empty user playlist with the given title.
    @discardableResult
    func createPlaylist(title: String) -> Playlist {
        let playlist = Playlist(title: title)
        context.insert(playlist)
        try? context.save()
        return playlist
    }

    /// Append a song to an existing playlist.
    func add(_ song: Song, to playlist: Playlist) {
        if !playlist.songs.contains(where: { $0.persistentModelID == song.persistentModelID }) {
            playlist.songs.append(song)
            try? context.save()
        }
    }

    /// Remove a song from a playlist (song stays in library).
    func remove(_ song: Song, from playlist: Playlist) {
        playlist.songs.removeAll { $0.persistentModelID == song.persistentModelID }
        try? context.save()
    }

    // MARK: — Songs

    func delete(_ song: Song) {
        context.delete(song)
        try? context.save()
    }

    func delete(_ songs: [Song]) {
        for song in songs { context.delete(song) }
        try? context.save()
    }

    // MARK: — Listen events

    /// Log a play / skip event. Called from `AudioEngine` when a song
    /// completes OR is skipped past ~10 seconds (the latter threshold
    /// is decided by the audio engine — this method just records).
    ///
    /// Takes scalar values + `PersistentIdentifier` so it can be called
    /// from any actor (in practice, `@MainActor` today via SwiftUI).
    func logListenEvent(
        songID: PersistentIdentifier,
        playedDuration: TimeInterval,
        completed: Bool
    ) {
        guard let song = context.model(for: songID) as? Song else { return }
        let event = ListenEvent(
            playedDuration: playedDuration,
            completed: completed,
            song: song
        )
        context.insert(event)
        song.lastPlayed = Date()
        if completed { song.playCount += 1 }
        try? context.save()
    }

    /// Increment `playCount` without writing a ListenEvent (used when
    /// the user taps a song to start it — not yet 10 seconds in).
    func recordTap(_ song: Song) {
        song.lastPlayed = Date()
        try? context.save()
    }

    // MARK: — Smart playlist queries

    /// Songs flagged as favorite, sorted by title.
    func favoriteSongs() -> [Song] {
        let predicate = #Predicate<Song> { $0.isFavorite == true }
        let descriptor = FetchDescriptor<Song>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    /// "Most Played" — sorted by `playCount` descending.
    func mostPlayedSongs(limit: Int? = nil) -> [Song] {
        var descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { $0.playCount > 0 },
            sortBy: [SortDescriptor(\.playCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// "Recently Played" — sorted by `lastPlayed` descending, only
    /// songs that have actually been played at least once.
    func recentlyPlayedSongs(limit: Int? = nil) -> [Song] {
        var descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { $0.lastPlayed != nil },
            sortBy: [SortDescriptor(\.lastPlayed, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
