import XCTest
import SwiftData
import Lunar
@testable import Lunar

@MainActor
final class LibraryServiceTests: XCTestCase {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: LunarSchema.schema, configurations: config)
    }

    func test_toggleFavorite_flipsFlagAndPersists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)
        let song = Song(title: "Wake Up", artist: "Arcadify", fileName: "a.m4a")
        context.insert(song)
        try? context.save()

        XCTAssertFalse(song.isFavorite)
        XCTAssertTrue(service.toggleFavorite(song))
        XCTAssertTrue(song.isFavorite)
        XCTAssertFalse(service.toggleFavorite(song))
        XCTAssertFalse(song.isFavorite)
    }

    func test_createPlaylist_appendsAndPersists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let p1 = service.createPlaylist(title: "Favorites")
        XCTAssertEqual(p1.title, "Favorites")
        XCTAssertFalse(p1.isSystemPlaylist)
        XCTAssertTrue(p1.songs.isEmpty)

        let s1 = Song(title: "Dog Days Are Over", artist: "Florence", fileName: "x.m4a")
        context.insert(s1)
        service.add(s1, to: p1)
        XCTAssertEqual(p1.songs.count, 1)
        XCTAssertEqual(p1.songs.first?.title, "Dog Days Are Over")
    }

    func test_addSong_isIdempotent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let song = Song(title: "Echoes", artist: "Pink Floyd", fileName: "y.m4a")
        context.insert(song)
        let playlist = service.createPlaylist(title: "Classics")

        service.add(song, to: playlist)
        service.add(song, to: playlist)
        service.add(song, to: playlist)

        XCTAssertEqual(playlist.songs.count, 1)
    }

    func test_deleteSong_removesFromContext() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let song = Song(title: "Creep", artist: "Radiohead", fileName: "z.m4a")
        context.insert(song)
        try? context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Song>()), 1)

        service.delete(song)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Song>()), 0)
    }

    func test_logListenEvent_incrementsPlayCountOnCompletion() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let song = Song(title: "Strobe", artist: "deadmau5", fileName: "q.m4a")
        context.insert(song)
        try? context.save()

        XCTAssertEqual(song.playCount, 0)
        XCTAssertNil(song.lastPlayed)

        service.logListenEvent(
            songID: song.persistentModelID,
            playedDuration: 604,
            completed: true
        )
        XCTAssertEqual(song.playCount, 1)
        XCTAssertNotNil(song.lastPlayed)
        let events = try context.fetch(FetchDescriptor<ListenEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.playedDuration, 604)
        XCTAssertTrue(events.first?.completed == true)
    }

    func test_mostPlayed_descendingByPlayCount() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let sA = Song(title: "A", artist: "X", fileName: "a.m4a")
        let sB = Song(title: "B", artist: "X", fileName: "b.m4a")
        let sC = Song(title: "C", artist: "X", fileName: "c.m4a")
        for s in [sA, sB, sC] { context.insert(s) }
        try? context.save()

        service.logListenEvent(songID: sA.persistentModelID, playedDuration: 60, completed: true)
        for _ in 0..<3 { service.logListenEvent(songID: sB.persistentModelID, playedDuration: 60, completed: true) }
        for _ in 0..<2 { service.logListenEvent(songID: sC.persistentModelID, playedDuration: 60, completed: true) }

        let top = service.mostPlayedSongs()
        XCTAssertEqual(top.map(\.title), ["B", "C", "A"])
    }

    func test_recentlyPlayed_returnsOnlyPlayedSongs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let sPlayed = Song(title: "Played", artist: "X", fileName: "p.m4a")
        let sUntouched = Song(title: "Untouched", artist: "Y", fileName: "u.m4a")
        context.insert(sPlayed); context.insert(sUntouched)
        try? context.save()

        service.recordTap(sPlayed)   // lastPlayed set, but playCount = 0

        let recent = service.recentlyPlayedSongs()
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.title, "Played")
    }

    func test_favoriteSongs_predicateMatchesFlag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = LibraryService(context: context)

        let s = Song(title: "Pet", artist: "Owner", fileName: "pet.m4a")
        context.insert(s)
        try? context.save()

        XCTAssertTrue(service.favoriteSongs().isEmpty)
        service.toggleFavorite(s)
        let favs = service.favoriteSongs()
        XCTAssertEqual(favs.count, 1)
        XCTAssertEqual(favs.first?.title, "Pet")
    }
}
