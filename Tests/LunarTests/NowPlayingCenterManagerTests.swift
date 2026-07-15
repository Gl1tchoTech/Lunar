import XCTest
import SwiftData
import MediaPlayer
@testable import Lunar

/// Tests for `NowPlayingCenterManager` — focuses on the no-network,
/// no-AVFoundation-runtime surfaces that we can isolate cleanly:
///
/// - **Artwork cache**: the resolver closure is called **once per song**
///   even when `update(_:songID:)` fires many times for the same song.
/// - **Diff skip**: `update(_:songID:)` is suppressed when both the
///   state and the song ID match the previous call — critical for the
///   0.1 s progress tick path.
/// - **`attach()` gate**: updates before `attach()` are silently dropped
///   (so we don't race the Lock Screen registration).
///
/// We do NOT exercise the iOS-system `MPRemoteCommandCenter` handler
/// dispatch in this file; testing it requires standing up the system
/// singletons which is brittle in xctest. The wiring uses Apple's
/// documented contract; manual QA on device covers end-to-end.
///
/// **Why a real SwiftData container?** `PersistentIdentifier` is opaque
/// — there's no public initializer. The only honest way to produce a
/// distinct, hashable, equatable value is to insert a real `Song`
/// into an in-memory `ModelContainer` and grab `.persistentModelID`.
/// This also incidentally verifies the resolver closure / SwiftData
/// integration that `LunarAppCoordinator` will use in production.
@MainActor
final class NowPlayingCenterManagerTests: XCTestCase {

    private var engine: AudioEngine!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var resolverCalls: [PersistentIdentifier] = []
    private var resolverResponses: [PersistentIdentifier: Data] = [:]

    override func setUp() async throws {
        try await super.setUp()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        resolverCalls.removeAll()
        resolverResponses.removeAll()

        container = try ModelContainer(
            for: LunarSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        engine = AudioEngine()
    }

    override func tearDown() async throws {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        engine = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Artwork cache

    func test_resolver_isCalledOnce_whenSameSongID_pushedWithSameState() throws {
        let song = try insertSong(title: "Cache A", hasArtwork: true)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in
                resolverCalls.append(id)
                return resolverResponses[id]
            }
        )
        manager.attach()

        let state = makeState(title: "Cache A", artist: "Artist")
        manager.update(state, currentSongID: song.persistentModelID)
        manager.update(state, currentSongID: song.persistentModelID)

        XCTAssertEqual(
            resolverCalls, [song.persistentModelID],
            "Resolver must run exactly once per song when state and songID are unchanged."
        )
    }

    func test_resolver_doesNotRun_whenStateDiffers_butSongIDUnchanged() throws {
        // The whole point of the on-song-change artwork gating is
        // that the cache hits whenever a song plays continuously.
        // Same songID + different PlayerState = cache hit, no resolve.
        let song = try insertSong(title: "Hibernate", hasArtwork: true)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in
                resolverCalls.append(id)
                return resolverResponses[id]
            }
        )
        manager.attach()

        let paused = makeState(title: "Hibernate", artist: "Muse", isPlaying: false)
        let playing = paused  // <-- same PlayerState (diff skip)
        manager.update(paused, currentSongID: song.persistentModelID)
        manager.update(playing, currentSongID: song.persistentModelID)

        XCTAssertEqual(resolverCalls, [song.persistentModelID])

        // Now do push a different state (resume) — diff guard passes,
        // but the artwork cache should already have the entry so
        // the resolver is NOT called again.
        let playingResumed = makeState(title: "Hibernate", artist: "Muse", isPlaying: true, time: 1.0)
        manager.update(playingResumed, currentSongID: song.persistentModelID)

        XCTAssertEqual(
            resolverCalls, [song.persistentModelID],
            "Same songID across different states: artwork cache must hit and skip the resolver."
        )
    }

    func test_resolver_runsAgain_whenSongIDChanges() throws {
        let songA = try insertSong(title: "A", hasArtwork: true)
        let songB = try insertSong(title: "B", hasArtwork: true)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in
                resolverCalls.append(id)
                return resolverResponses[id]
            }
        )
        manager.attach()

        manager.update(makeState(title: "A"), currentSongID: songA.persistentModelID)
        manager.update(makeState(title: "B"), currentSongID: songB.persistentModelID)

        XCTAssertEqual(
            resolverCalls,
            [songA.persistentModelID, songB.persistentModelID],
            "Different songID always re-resolves (cache miss)."
        )
    }

    func test_artworkResolver_returningNil_doesNotPushArtwork() throws {
        // No artwork bytes — resolver returns nil. The dict must
        // still publish title/duration/etc., it just must NOT have
        // an artwork key.
        let song = try insertSong(title: "Plain", hasArtwork: false)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in
                resolverCalls.append(id)
                return resolverResponses[id]  // nil because we set nothing
            }
        )
        manager.attach()

        manager.update(
            makeState(title: "Plain", artist: "Artist"),
            currentSongID: song.persistentModelID
        )

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(info, "Center must publish even without artwork.")
        XCTAssertNil(info?[MPMediaItemPropertyArtwork])
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Plain")
    }

    func test_update_beforeAttach_isNoOp() throws {
        let song = try insertSong(title: "Never", hasArtwork: true)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in
                resolverCalls.append(id)
                return resolverResponses[id]
            }
        )
        // Deliberately don't call `attach()`.

        manager.update(
            makeState(title: "Never", artist: "—"),
            currentSongID: song.persistentModelID
        )

        XCTAssertEqual(resolverCalls, [],
                       "Resolver must not run before attach().")
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func test_detach_clearsPublishedInfo() throws {
        let song = try insertSong(title: "Bye", hasArtwork: true)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in resolverResponses[id] }
        )
        manager.attach()
        manager.update(
            makeState(title: "Bye"),
            currentSongID: song.persistentModelID
        )
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)

        manager.detach()
        XCTAssertNil(
            MPNowPlayingInfoCenter.default().nowPlayingInfo,
            "detach() must clear MPNowPlayingInfoCenter."
        )
        XCTAssertEqual(resolverCalls.count, 1)
    }

    func test_attach_isIdempotent() throws {
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { _ in nil }
        )
        manager.attach()
        manager.attach()  // second call is a no-op
        // Direct assertion on handler registration would require
        // poking iOS system singletons, so we just exercise the
        // idempotent path and confirm no crash / no duplicate work
        // would later cause spurious remote-command dispatch.
        let song = try insertSong(title: "Idem", hasArtwork: false)
        manager.update(
            makeState(title: "Idem"),
            currentSongID: song.persistentModelID
        )
        XCTAssertNotNil(
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle]
        )
    }

    // MARK: - Info dict contract

    func test_pushedInfo_carriesAllExpectedKeys() throws {
        let song = try insertSong(title: "Title", artist: "Artist", hasArtwork: true)
        let manager = NowPlayingCenterManager(
            audioEngine: engine,
            artworkResolver: { id in resolverResponses[id] }
        )
        manager.attach()

        let state = PlayerState(
            currentTitle: "Title",
            currentArtist: "Artist",
            isPlaying: true,
            currentTime: 42.5,
            duration: 200,
            volume: 0.7
        )
        manager.update(state, currentSongID: song.persistentModelID)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Title")
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "Artist")
        XCTAssertEqual(info?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, 200)
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval, 42.5)
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
        XCTAssertEqual(info?[MPNowPlayingInfoPropertyDefaultPlaybackRate] as? Double, 1.0)
        XCTAssertEqual(
            info?[MPNowPlayingInfoPropertyMediaType] as? UInt,
            MPNowPlayingInfoMediaType.audio.rawValue
        )
    }

    // MARK: - Helpers

    /// Insert a real SwiftData `Song` so we get a meaningful
    /// `PersistentIdentifier`. The optional artwork payload is
    /// seeded into `resolverResponses` keyed by that identifier so
    /// the manager's lookup closure returns the bytes we expect.
    @discardableResult
    private func insertSong(
        title: String,
        artist: String = "Test Artist",
        hasArtwork: Bool
    ) throws -> Song {
        let bytes: Data? = hasArtwork ? makePNGData() : nil
        let song = Song(
            title: title,
            artist: artist,
            duration: 0,
            fileName: "\(UUID().uuidString).mp3",
            artwork: bytes
        )
        context.insert(song)
        try context.save()
        if let bytes {
            resolverResponses[song.persistentModelID] = bytes
        }
        return song
    }

    private func makeState(
        title: String,
        artist: String = "Artist",
        isPlaying: Bool = true,
        time: TimeInterval = 12.34
    ) -> PlayerState {
        PlayerState(
            currentTitle: title,
            currentArtist: artist,
            isPlaying: isPlaying,
            currentTime: time,
            duration: 200,
            volume: 0.8
        )
    }

    /// 1×1 PNG generated programmatically so the tests don't depend
    /// on a fixture file. `UIImage(data:)` happily decodes this.
    private func makePNGData() -> Data {
        // Minimal valid 1×1 transparent PNG bytes (the standard
        // "smallest PNG" hex blob).
        let hex = "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c63000100000005000100c9d1c7eb0000000049454e44ae426082"
        var data = Data()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let byte = UInt8(hex[idx..<next], radix: 16) {
                data.append(byte)
            }
            idx = next
        }
        return data
    }
}
