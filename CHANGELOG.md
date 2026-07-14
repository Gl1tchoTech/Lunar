# Changelog

All notable changes to **Lunar** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Step 4 — Feature wiring: Library sub-tabs · Now Playing + Mini Player · Playlists · Settings (in progress)

- **AudioEngine.queue** — in-memory `[PlaybackRequest]` + queueIndex. New methods: `playQueue(_:startIndex:)`, `enqueueNext(_:)`, `next()`, `previous()`. `handleNextNodeCompleted` auto-advances. `isTransitioning` flag gates rapid `next`/`previous` taps. `onSongFinished` callback fires for `LibraryService.logListenEvent` (wired in Step 5).
- **Library sub-tabs (Artists / Albums / Source)** — real `@Query` views replacing the Step-1 stubs. Each row pushes a detail view (`ArtistDetailView`, `AlbumDetailView`).
- **Now Playing** — full-screen cover with Player-Theme gradient background, large artwork card, title/artist block, scrub bar, 5-button transport row. Launched via `.fullScreenCover` from the Mini Player dock.
- **MiniPlayer** — persistent pill docked via `.safeAreaInset(edge: .bottom)` on Library / Playlist / Import. Hidden when no song is loaded. Tap opens Now Playing.
- **ScrubBar** — slider bound to `AudioEngine.state.duration` / `currentTime` with m:ss labels. Seeks via `engine.send(.seek(t))`.
- **TransportRow** — shuffle / previous / play-pause / next / repeat. Disables prev/next at queue ends.
- **Playlist tab full rewrite** — `NavigationStack(path:)` drives a list of smart-playlist tiles + local playlists + Create New alert. Smart tiles (`Most Played`, `Recently Played`) push `PlaylistDetailView` with gradient hero. User playlists push with `icon`/`heart` heroes.
- **PlaylistDetailView** — hero card (gradient/icon/heart) + LibraryActionRow + song list. Tap a song → `LibraryService.playbackRequests(for:startingAt:)` → `audioEngine.playQueue(requests)` + Now Playing cover.
- **LibraryService.playbackRequests** — `[Song] → [PlaybackRequest]` builder. Skips songs missing on disk. Has `startingAt:` variant for tap-from-middle.
- **PlayerStyleView** — Settings → Player Style. Vertical list of six theme preview cards (gradient + accent play button + transport pills).
- **AppThemeView + AppThemeSettings** — Settings → App Theme. System/Light/Dark segmented picker + 3-column accent swatch grid (Purple/Pink/Cyan/Orange/Green/Red). Persists to `UserDefaults`; drives `WindowGroup.preferredColorScheme` and accent tint.
- **SettingsView + LibraryView + ImportView rewires** — stubs replaced with real sub-views. Library/Playlist/Import get the Now Playing fullScreenCover + MiniPlayer safeAreaInset.

### Step 3 — Core library layer + Audio engine + Library Songs tab (in progress)

- **`MusicLibrary`** (`Lunar/Sources/Core/Library/MusicLibrary.swift`) — sandbox-aware helpers: `ensureLibraryDirectory()`, `absoluteURL(forFileName:)` rebuilds the `Song.fileName`-→-`URL` mapping under `Application Support/Music/`.
- **`LibraryService`** (`Lunar/Sources/Core/Library/LibraryService.swift`) — `@MainActor` SwiftData façade: `toggleFavorite`, `createPlaylist`, `add`/`remove` from playlist, `delete`, `logListenEvent(songID:)`, smart-playlist queries (`favoriteSongs`, `mostPlayedSongs`, `recentlyPlayedSongs`).
- **`AudioPlayerInterface`** (`Lunar/Sources/Core/Audio/PlayerProtocol.swift`) — `@MainActor` protocol + `PlaybackCommand` enum + `Sendable` `PlaybackRequest`. Views + tests + fakes talk through one API surface.
- **`AudioEngine`** (`Lunar/Sources/Core/Audio/AudioEngine.swift`) — real `AVAudioEngine`-backed player, `@MainActor @Observable`. **Frozen graph** (`playerA / playerB / timePitch / eq / mainMixer`) built once at init; 0.1 s progress ticker; 60 Hz crossfade volume ramp; off-thread `AVAudioFile` decode via `Task.detached`.
- **`EQController`** (`Lunar/Sources/Core/Audio/EQController.swift`) — 10-band ISO EQ with gain clamp ±12 dB; `makeUnit()`, `apply(bands:to:)`, `bypass(_:)`.
- **`SleepTimer`** (`Lunar/Sources/Core/Audio/SleepTimer.swift`) — `@MainActor @Observable` countdown for 5 / 15 / 30 / 45 / 60 minutes or Off; persisted to `UserDefaults`; fires `onExpire` callback.
- **`AppAudioSession`** (`Lunar/Sources/Core/Audio/AppAudioSession.swift`) — `.playback` category + interruption + route-change observers pushed through `PassthroughSubject<AudioEvent, Never>`. `.receive(on: DispatchQueue.main)` keeps handlers on the main actor.
- **`LunarApp`** + **`LunarAppCoordinator`** — inject `AudioEngine` + `SleepTimer` into the SwiftUI environment. Private coordinator handles the once-only `audioEngine.attach(session:)` + `sleepTimer.onExpire → engine.pause()` glue in its `.task` modifier.
- **`LibraryView` refactor** — Step 1 placeholder replaced with a working **Songs** tab: tab strip (Songs · Artists · Albums · Source), sort-menu chip (`↑↓ Artist name (N)`), lime shuffle + play pills, `@Query(Song)` rows with swipe + context menu, empty state. Artists / Albums / Source remain stubs.
- New components: `SongRow` (artwork + title + artist + duration), `SortMenu` (sheet with two grouped sections + checkmarks), `LibraryActionRow` (shuffle / play pills).
- Tests: `LibraryServiceTests` (8), `AudioEngineControllerTests` with `FakeAudioEngine` + `EQController` (9).

## [0.3.0] — Step 3: Core library + audio engine + Library Songs tab

(verified on push)

## [0.2.0] — Step 2: SwiftData layer

### Added
- **`Song`** — `@Model` with full audio metadata (file path, codec info, size). `isFavorite`, `playCount`, `lastPlayed`, `dateAdded`. `artwork` uses `@Attribute(.externalStorage)` for scroll performance. Relationships: `album (Album?)`, `artistEntity (Artist?)`, `listenEvents ([ListenEvent])` with `.cascade`.
- **`Album`** — title, denormalized `artist`, optional `year`, external-storage artwork. `songs: [Song]` with `.nullify` inverse.
- **`Artist`** — name, optional `bio`, external-storage artwork. `songs: [Song]` with `.nullify` inverse.
- **`Playlist`** — many-to-many `songs: [Song]`. `isSystemPlaylist` flag reserved for future system-curated collections. **Favorites are NOT stored here** — they are queried via `#Predicate<Song> { $0.isFavorite }`.
- **`ListenEvent`** — `timestamp`, `playedDuration`, `completed`. Inverse declared on `Song.listenEvents` for automatic cascade cleanup.
- **`EQPreset`** — 10-band native `[Float]` (SwiftData auto-Codable). `isBuiltIn` flag prevents user deletion of factory presets.
- **`LunarSchema`** — central registry used by `LunarApp` and test helpers.
- **`BuiltInEQPresets`** — 13 factory presets (Flat / Acoustic / Bass Booster / Bass Reducer / Classical / Dance / Electronic / Hip-Hop / Jazz / Pop / R&B / Rock / Vocal Booster) seeded **only on first launch**.
- **`ModelContainer` wired in `LunarApp`** — explicit `init()` with `Schema(LunarSchema.models)` and `fatalError` fallback for unrecoverable store failures.
- **`ModelTests`** (`Tests/LunarTests/ModelTests.swift`) — 7 tests covering empty-store invariants, init defaults, schema round-trip, relationship wiring, and seeding.

### Schema design notes
- **`Song.fileName` is a relative path.** Sandbox absolute URLs rot on app update/restore; we resolve to a real URL at read time (`MusicLibrary.absoluteURL(forFileName:)` once that helper ships in Step 3+).
- **Denormalized fields** (`Song.artist`, `Song.albumTitle`, `Album.artist`) enable fast `@Query` `SortDescriptor` queries — iOS 17 SwiftData has known performance issues sorting through relationships.
- **`@Attribute(.externalStorage)` on artwork** keeps image blobs out of SQLite row fetches.
- **Playlists do not yet preserve song order** — iOS 17 SwiftData does not natively support ordered many-to-many. Until a `PlaylistEntry` join entity is introduced, songs in a playlist view are sorted by `dateAdded` per `FetchDescriptor`.

### Step 2 open work (for Step 3+)
- `PlaylistEntry` for explicit ordering & drag-to-reorder
- `MusicLibrary` helper that resolves the relative `fileName` to a sandbox-abs `URL`
- `LibraryService` — façade for mutations (toggleFavorite, createPlaylist, deleteSong) so views never call `context.save()` directly

## [0.1.0] — 2026-07-14

### Added
- Project scaffold: Xcode-ready SwiftUI app via XcodeGen
- Design tokens (`ColorTokens`, `Typography`, `Spacing`)
- 6 Player Themes (Cyber Neon, Vinyl / Lime, Aurora, Vivid Ocean, Sepia Wood, Pastel Playful)
- `@Observable` `PlayerThemeManager` with UserDefaults persistence
- `EmptyState` component reused by every list-style screen
- 5-tab shell: **Library · Playlist · Import · Browse · Settings**
- iPad split view via `NavigationSplitView`, iPhone via `TabView`
- Placeholder feature views for all 5 destinations
- Browse tab cartography (categories grid + "Coming soon" footnote)
- GitHub Action producing **unsigned** `.ipa` artifact for SideStore
- `Scripts/build-ipa.sh` local runner
- Documentation: `docs/SIDESTORE.md`, `docs/BUILD.md`

### Notes
- App starts **empty**: there are no bundled songs, seed albums, or placeholder library data.
- The `Browse` tab is a placeholder grid for the upcoming song downloader/streamer.
- All `PRO` / lock indicators from the reference design are intentionally absent — Lunar is fully free.

## [0.0.0] — 2026

Project initialized.
