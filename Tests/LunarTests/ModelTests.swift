import XCTest
import SwiftData
@testable import Lunar

@MainActor
final class ModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LunarSchema.schema,
            configurations: config
        )
    }

    // MARK: - Tests

    func test_emptyStore_startsEmpty_noSeedLibrary() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Song>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Album>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Artist>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Playlist>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ListenEvent>()), 0)
        // Test container bypasses LunarApp's seeding, so EQ presets are also empty.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EQPreset>()), 0)
    }

    func test_songInit_setsSafeDefaults() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let song = Song(
            title: "Test Song",
            artist: "Anthropic Symphony",
            duration: 210,
            fileName: "test.mp3"
        )
        context.insert(song)
        try context.save()

        XCTAssertEqual(song.title, "Test Song")
        XCTAssertEqual(song.artist, "Anthropic Symphony")
        XCTAssertEqual(song.duration, 210)
        XCTAssertEqual(song.fileName, "test.mp3")
        XCTAssertEqual(song.playCount, 0)
        XCTAssertFalse(song.isFavorite)
        XCTAssertNil(song.lastPlayed)
        XCTAssertNil(song.albumTitle)
        XCTAssertNil(song.artwork)
        XCTAssertNil(song.album)
        XCTAssertNil(song.artistEntity)
        // Relationships are now safe to read after `insert`.
        XCTAssertTrue(song.listenEvents.isEmpty)
    }

    func test_playlist_systemFlag_isQueryable() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let p = Playlist(title: "My Favorites", isSystemPlaylist: true)
        context.insert(p)
        try context.save()
        XCTAssertTrue(p.isSystemPlaylist)
        XCTAssertTrue(p.songs.isEmpty)
    }

    func test_eqPreset_bandsNativeArray() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let preset = EQPreset(
            name: "Custom",
            isBuiltIn: false,
            bands: [1.0, -2.0, 3.5, 0.5, -1.0, 2.0, 0, 0, 0, 4.0],
            dateCreated: Date()
        )
        context.insert(preset)
        try context.save()

        XCTAssertEqual(preset.bands.count, 10)
        XCTAssertEqual(preset.bands[0], 1.0)
        XCTAssertEqual(preset.bands[9], 4.0)
    }

    func test_song_roundtripsThroughContext() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let song = Song(
            title: "Round Trip",
            artist: "Test Artist",
            albumTitle: "Test Album",
            duration: 200,
            fileName: "rt.mp3"
        )
        context.insert(song)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Round Trip")
        XCTAssertEqual(fetched.first?.albumTitle, "Test Album")
        XCTAssertEqual(fetched.first?.fileName, "rt.mp3")
    }

    func test_eqPreset_roundtripsThroughContext() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let preset = EQPreset(
            name: "Roundtrip EQ",
            isBuiltIn: false,
            bands: [2, -3, 4, -1, 0, 1, -2, 3, 5, -4],
            dateCreated: Date()
        )
        context.insert(preset)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<EQPreset>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.bands, [2, -3, 4, -1, 0, 1, -2, 3, 5, -4])
    }

    func test_eqPreset_bandMutation_requiresWholeArrayReplacement() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let preset = EQPreset(
            name: "Mutable",
            isBuiltIn: false,
            bands: Array(repeating: Float(0), count: 10),
            dateCreated: Date()
        )
        context.insert(preset)
        try context.save()

        // ⚠️ iOS 17 SwiftData doesn't observe in-place array element
        // changes. The supported pattern is: copy, mutate, reassign.
        var updated = preset.bands
        updated[2] = 5.0
        preset.bands = updated
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<EQPreset>())
        XCTAssertEqual(fetched.first?.bands[2], 5.0)
    }

    func test_seedBuiltInEQPresets_seedsThirteenPresets_onFirstCall() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EQPreset>()), 0)

        // Computed `presets` yields a fresh batch of @Model instances,
        // safe to insert into this in-memory container independent
        // of any other container's seeding.
        for preset in BuiltInEQPresets.presets {
            context.insert(preset)
        }
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<EQPreset>())
        XCTAssertEqual(count, BuiltInEQPresets.presets.count)

        let builtInCount = try context.fetchCount(
            FetchDescriptor<EQPreset>(predicate: #Predicate { $0.isBuiltIn == true })
        )
        XCTAssertEqual(builtInCount, BuiltInEQPresets.presets.count)
    }

    func test_relationship_songArtistAlbum_wireup() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let artist = Artist(name: "Test Artist")
        let album = Album(title: "Test Album", artist: "Test Artist")
        let song = Song(
            title: "Song 1",
            artist: "Test Artist",
            albumTitle: "Test Album",
            duration: 120,
            fileName: "song1.mp3"
        )

        song.artistEntity = artist
        song.album = album
        context.insert(artist)
        context.insert(album)
        context.insert(song)
        try context.save()

        XCTAssertEqual(artist.songs.count, 1)
        XCTAssertEqual(album.songs.count, 1)
        XCTAssertEqual(song.artistEntity?.name, "Test Artist")
        XCTAssertEqual(song.album?.title, "Test Album")
    }
}
