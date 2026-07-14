# Changelog

All notable changes to **Lunar** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned (Step 3+)
- AVAudioEngine-based playback: real DSP, gapless, crossfade
- 10-band EQ view (data layer already shipped in 0.2.0)
- Lyrics (.lrc manual import)
- Sleep timer
- Smart playlists (Most Played / Recently Played) — Predicates already shipped in 0.2.0
- Full Now Playing screen + sheets
- Settings rows (Player Style · App Theme · Equalizer · Playback · Language · Backup)
- Library tabs: Songs sorts, Artists / Albums / Source
- Playlist tab + Create flow
- Import: Local Files · Wi-Fi Drive · Cloud
- Browse: downloader / streamer

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
