import XCTest
import SwiftData
import Lunar
@testable import Lunar

/// Pure-function tests for `SongSearch.filter(_:by:)` — the search
/// helper used by `SongsListView`. Replaces an ad-hoc inline filter
/// so the matching contract is testable without a SwiftUI host and
/// searchable host.
///
/// Contract pinned:
/// - Empty / whitespace-only query → return input verbatim (not `[]`).
/// - Match against `title`, `artist`, `albumTitle`
///   (case-insensitive via `localizedLowercase`).
/// - Nil `albumTitle` does not crash and does not match.
@MainActor
final class LibrarySearchTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: LunarSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeSong(
        title: String,
        artist: String,
        album: String? = nil,
        container: ModelContainer
    ) -> Song {
        let song = Song(
            title: title,
            artist: artist,
            albumTitle: album,
            fileName: "\(title)-\(UUID().uuidString).m4a"
        )
        container.mainContext.insert(song)
        return song
    }

    func test_emptyQuery_returnsInputVerbatim() throws {
        let container = try makeContainer()
        let songs = ["A", "B", "C"].map {
            makeSong(title: $0, artist: "X", container: container)
        }
        let result = SongSearch.filter(songs, by: "")
        XCTAssertEqual(result.map(\.title), songs.map(\.title))
    }

    func test_whitespaceOnlyQuery_returnsInputVerbatim() throws {
        let container = try makeContainer()
        let songs = ["A", "B"].map {
            makeSong(title: $0, artist: "X", container: container)
        }
        let result = SongSearch.filter(songs, by: "    ")
        XCTAssertEqual(result.map(\.title), songs.map(\.title))
    }

    func test_trimsSurroundingWhitespace_inQuery() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "Creep", artist: "Radiohead", container: container)
        let s2 = makeSong(title: "Other", artist: "A", container: container)
        // "  creep  " should still match "Creep".
        let result = SongSearch.filter([s1, s2], by: "  creep  ")
        XCTAssertEqual(result.map(\.title), ["Creep"])
    }

    func test_titleCase_insensitiveMatch() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "Creep", artist: "Radiohead", container: container)
        let s2 = makeSong(title: "Karma Police", artist: "Radiohead", container: container)
        let result = SongSearch.filter([s1, s2], by: "creep")
        XCTAssertEqual(result.map(\.title), ["Creep"])
    }

    func test_upperCase_insensitiveMatch() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "Creep", artist: "Radiohead", container: container)
        let s2 = makeSong(title: "Karma Police", artist: "Radiohead", container: container)
        let result = SongSearch.filter([s1, s2], by: "CREEP")
        XCTAssertEqual(result.map(\.title), ["Creep"])
    }

    func test_artistFieldMatches() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "Creep", artist: "Radiohead", container: container)
        let s2 = makeSong(title: "Strobe", artist: "deadmau5", container: container)
        let s3 = makeSong(title: "Pets",  artist: "Porno for Pyros", container: container)
        let result = SongSearch.filter([s1, s2, s3], by: "deadmau5")
        XCTAssertEqual(result.map(\.title), ["Strobe"])
    }

    func test_albumFieldMatches() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "Airbag", artist: "Radiohead",
                          album: "OK Computer", container: container)
        let s2 = makeSong(title: "Creep",  artist: "Radiohead",
                          album: "Pablo Honey", container: container)
        let s3 = makeSong(title: "Strobe", artist: "deadmau5",
                          album: "Random Album Title", container: container)
        let result = SongSearch.filter([s1, s2, s3], by: "Pablo")
        XCTAssertEqual(result.map(\.title), ["Creep"])
    }

    func test_nilAlbum_doesNotMatchAlbumQuery() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "No Album Track", artist: "X",
                          album: nil, container: container)
        let s2 = makeSong(title: "Albumed", artist: "X",
                          album: "Hits", container: container)
        let result = SongSearch.filter([s1, s2], by: "Hits")
        // Both have an artist that includes "X" so… but our query
        // is "Hits" — only s2 has "Hits" as an album.
        XCTAssertEqual(result.map(\.title), ["Albumed"])
    }

    func test_diacriticInsensitiveMatch() throws {
        let container = try makeContainer()
        let s = makeSong(title: "Café", artist: "Y", container: container)
        let result = SongSearch.filter([s], by: "cafe")
        XCTAssertEqual(result.map(\.title), ["Café"])
    }

    func test_partialMatchInMiddleOfTitle() throws {
        let container = try makeContainer()
        let s1 = makeSong(title: "Bohemian Rhapsody", artist: "Queen", container: container)
        let s2 = makeSong(title: "Radio Ga Ga",       artist: "Queen", container: container)
        let result = SongSearch.filter([s1, s2], by: "rhaps")
        XCTAssertEqual(result.map(\.title), ["Bohemian Rhapsody"])
    }

    func test_noMatch_returnsEmpty() throws {
        let container = try makeContainer()
        let songs = ["A", "B"].map {
            makeSong(title: $0, artist: "X", container: container)
        }
        let result = SongSearch.filter(songs, by: "ZZZ_NEVER_MATCHES")
        XCTAssertTrue(result.isEmpty)
    }

    func test_partialMatchAcrossTitleAndArtist_combined() throws {
        // An artist with "radio" in the name should match a query
        // for "radio" even when no title matches.
        let container = try makeContainer()
        let s1 = makeSong(title: "Echoes", artist: "Pink Floyd", container: container)
        let s2 = makeSong(title: "Lucky",  artist: "Radiohead", container: container)
        let result = SongSearch.filter([s1, s2], by: "Radio")
        XCTAssertEqual(result.map(\.title), ["Lucky"])
    }
}
