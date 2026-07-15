# Changelog

All notable changes to **Lunar** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Step 5 — Tier 4: Settings polish ✅

- **`AppMetadata`** (`Lunar/Sources/Core/Config/AppMetadata.swift`) — NEW single source of truth for app-level data: `version` (reads `CFBundleShortVersionString`), `build` (reads `CFBundleVersion`), `bundleIdentifier`, `displayName`, `repositoryURL` (`https://github.com/Gl1tchoTech/Lunar`), and `copyrightYear`. Computed once at process launch. `versionAndBuild` formats as `"<version> (<build>)"` so Views don't reimplement the layout. Falls back to `"unknown"` when keys are missing so misconfiguration surfaces loudly instead of silently in the UI.
- **`AboutView`** (`Lunar/Sources/Features/Settings/AboutView.swift`) — NEW real destination at **Settings ▸ About**. Four sections:
  1. **Identity** — `Version` (`LabeledContent` with `AppMetadata.versionAndBuild`, monospaced digits), `Build` (`monospacedDigit`), `Bundle` (full bundle ID, truncating middle, caption-sized, tertiary tint so it doesn't compete visually).
  2. **Source** — a Button-styled "Source on GitHub" row that calls `openURL(AppMetadata.repositoryURL)` + a `Link` row echoing the full URL. Section footer notes "Lunar is local-first. The source tree is the spec."
  3. **Credits** — UI (SwiftUI + iOS 17+) · Audio (AVAudioEngine + AVAudioUnitEQ) · Storage (SwiftData @Model) · Theme (Cyber Neon · Purple accent). All rows use the same `LabeledContent` shape as Identity for visual consistency.
  4. **Footer** — centered `🌙 Lunar` glyph followed by `Made with care in Xcode · © <current year>`. Year is computed via `Calendar.current.component(.year, from: Date())` so it stays accurate across midnight on Dec 31.
- **`SettingsView` cleanup**:
  - Removed the `Language` stub row + `languageStub` helper. iOS follows the device locale automatically and Lunar ships en-only; no per-app override is exposed.
  - Removed the inline duplicate Version / Build / Made-with section from the bottom of Settings — that data now lives in About.
  - Replaced the `equalizerStub` indirection with a direct `EqualizerView()` reference (the wrapper comment was dead weight).
  - Added a single `About` row in its own Section between the Settings section and the deliberate Stub rows (Feedback / Rate Us / Privacy).
- **`AppMetadataTests`** (`Tests/LunarTests/AppMetadataTests.swift`) — NEW, 7 tests. Pins: `version != "unknown"` + non-empty in test bundle; same for `build`; `versionAndBuild` contains parentheses + starts with `version` + ends with `build`; repo URL scheme `https` + host `github.com` + path `/Gl1tchoTech/Lunar` (catches accidental `git@…` SSH URLs the `Link` view wouldn't render); bundle ID equals `com.gl1tchotech.lunar`; copyright year equals current calendar year; display name equals `Lunar`.

### Step 5 — Tier 2 Part 4: Synced Lyrics (`.lrc` import)

- **`Song.lyricsFileName: String?`** — new SwiftData field on `Song`. Stores the *relative* file name inside `Application Support/Lyrics/`; never an absolute URL (sandbox path may rotate on update/restore). Mirrors `Song.fileName` semantics exactly.
- **`LyricsParser`** (`Lunar/Sources/Core/Library/LyricsParser.swift`) — NEW pure-Swift `.lrc` parser. Regex-free; walks the line char-by-char collecting `[mm:ss(.xx)]` timestamps and emits one `LyricLine` per timestamp. Tolerates CRLF / CR / LF line endings, strips a leading BOM, and skips metadata lines like `[ti:Title] [ar:Artist] [al:Album] [by:…] [offset:…]`. **Multi-timestamp lines** like `[00:12.50][00:48.20]chorus` produce two `LyricLine` entries sharing the same text. Internally uses `Scanner.scanDouble` for the seconds + fraction in a *single* scan so a value like `00:12.50` produces `12.5` (not `62` — which a `scanInt + scanString(".") + scanDouble` round trip would produce).
- **`LyricsLibrary`** (`Lunar/Sources/Core/Library/LyricsLibrary.swift`) — NEW file-system façade. Mirrors `MusicLibrary` conventions (`rootDirectory`, `_rootDirectoryOverride` for tests, `ensureLyricsDirectory()`). `LyricsLibraryError` covers `directoryUnavailable` and `fileNotFound`.
- **`LyricsImporter`** (`Lunar/Sources/Core/Library/LyricsImporter.swift`) — NEW `@MainActor` importer. Pipeline: `startAccessingSecurityScopedResource()` (deferred release) → `ensureLyricsDirectory()` → `Task.detached(priority: .userInitiated)` copy → main-actor parse + persist → `Song.lyricsFileName = "lyrics-<UUID>.lrc"` + `context.save()` → orphan-old-file cleanup. Re-imports delete the previous `.lrc` so we don't leak across rewrites. UTF-8 / UTF-16 / ISO-Latin-1 decoding fallback; surfaces `LyricsLibraryError.fileNotFound` for "undecodable" + "no timestamps" payloads. Adds the `UTType.lrcLyrics` extension that returns `UTType(filenameExtension: "lrc", conformingTo: .plainText)` so `fileImporter` accepts both `.lrc` and any `.txt` a user renamed.
- **`LyricsView`** (`Lunar/Sources/Features/NowPlaying/LyricsView.swift`) — NEW full-screen sheet. Resolves the playing song through `engine.currentSongID` + `modelContext.model(for:) as? Song` (single source of truth — sheet always renders for the right track even after queue advance). Three render states: **no song**, **no lyrics** (import button), **lyrics loaded** (auto-scrolling column). `LyricsNavigator.activeLine(in: at:)` does an O(log n) binary search of the line whose `time ≤ currentTime`. `ScrollViewReader` proxy animates scrolls when the line index moves by ±1 (natural progression) and snaps for `|Δ| > 1` (seek / crossfade / restart) so the user doesn't fly past the active line. Tap-to-seek calls `engine.send(.seek(line.time))`. After import the player **snaps to the first timestamp** so the user immediately sees the song synced to the very first line.
- **`LyricsChip`** — NEW chip in Now Playing top chrome (mirrors the existing `SleepTimerChip`). Tapping presents `LyricsView()` as a sheet.
- **Lyrics `LyricsView` + Import flow** — the user picks `.lrc` from any source app (Files, On My iPhone, AirDrop, etc.) via the system `fileImporter`. After import, the song's lyrics are stored in Application Support and the parsed lines render in the LyricsView on the next `LyricsView` open.

### Step 5 — Tier 3: System Hooks (Lock Screen, Remote Commands, AirPlay)

Lunar now feels like a real music player on the Lock Screen and in
Control Center. Three iOS-native surfaces wired end-to-end without
restructuring the existing audio pipeline.

- **`AudioEngine.onStateChange`** callback — `@MainActor` closure fired
  from every state-mutating site (`play/pause/seek/load/crossfade/
  tickProgress/setMasterVolume/handleNextNodeCompleted`). Backed by a
  `PlayerState.Equatable` diff against the last notified snapshot so
  repeated 0.1 s progress ticks don't spam listeners when nothing else
  has changed (captures the `next()` end-of-queue pause + `previous()`
  split paths too).
- **`NowPlayingCenterManager`** (`Lunar/Sources/Core/Audio/NowPlayingCenterManager.swift`)
  — NEW `@MainActor` `final class` that bridges the engine to:
  - **`MPNowPlayingInfoCenter`** — title / artist / duration / elapsed
    time / playback rate / default play rate / media type pushed into
    `default().nowPlayingInfo` on every state change (re-issue) under
    a structural Equatable guard.
  - **`MPRemoteCommandCenter.shared()`** — play / pause / togglePlayPause /
    nextTrack / previousTrack / skipForward (15 s) / skipBackward
    (15 s) / changePlaybackPosition handlers, each forwarding to
    `await engine.send(_)` from inside `Task { ... }`. `attach()` is
    idempotent and primes a title-less placeholder so Control Center
    shows the Lunar widget as soon as the app launches.
  - **Artwork cache** — `[PersistentIdentifier: MPMediaItemArtwork]`
    keyed by song; lazy UIImage decode via the injected
    `artworkResolver` closure, downscale to 600 pt on the longest
    side for memory safety, aspect-fit crop returned per requested
    bounds via `MPMediaItemArtwork(boundsSize:request:)`.
  - **`detach()`** cleared for completeness (clears now-playing info,
    deregisters commands) — not currently called but ready for future
    background-mode lifecycles.
- **`AirPlayRouteButton`** (`Lunar/Sources/Features/NowPlaying/AirPlayRouteButton.swift`)
  — NEW compact `UIViewRepresentable` over `AVRoutePickerView`,
  28 × 28 in a `Capsule` filled with `palette.railBackground` to
  match `SleepTimerChip` / `LyricsChip`. Sets both `tintColor`
  (inactive) and `activeTintColor` (active) from the player-theme
  palette so the glyph reads against the dark Cyber Neon
  background and the accent glows on active route.
- **`NowPlayingView.swift`** — `AirPlayRouteButton(palette: palette)`
  dropped into the top chrome between `LyricsChip` and the queue
  counter (single-row alignment preserved).
- **`LunarAppCoordinator` (in `LunarApp.swift`)** — gained a
  `modelContainer: ModelContainer` parameter; inside `.task`:
  - constructs `NowPlayingCenterManager(audioEngine:, artworkResolver:
    { id in container.mainContext.model(for: id) as? Song })`
  - keeps the manager alive via `@State private var nowPlayingManager`
  - calls `manager.attach()`, then installs
    `audioEngine.onStateChange = { [weak manager] state, _ in
    manager?.update(state, currentSongID: audioEngine.currentSongID) }`
- **`NowPlayingCenterManagerTests`** (`Tests/LunarTests/NowPlayingCenterManagerTests.swift`)
  — NEW test class (7 tests). Real in-memory `ModelContainer` +
  `Song` inserts to produce legit `PersistentIdentifier` values, with
  per-test bitmap fixtures from a synthetic 1×1 PNG hex blob.
  Covers: cache hit on identical push, cache hit on state change
  (same song), cache miss on song change, nil-artwork no-op,
  pre-attach no-op, `detach()` clears the system-side info,
  `attach()` is idempotent, and the pushed info dict carries every
  expected `MPMediaItemProperty*` / `MPNowPlayingInfoProperty*` key.

### Step 5 — Tier 2 Part 5: 10-Band Equalizer

- **`EQSettings`** (`Lunar/Sources/Core/Audio/EQSettings.swift`) — NEW `@MainActor @Observable final class`. Holds:
  - `bands: [Float]` (length `EQController.isoBandCentersHz.count` == **10**, defaults to all zeros; reshaped to flat on length drift).
  - `isEnabled: Bool` — default true (EQ engaged).
  - `currentPresetID: PersistentIdentifier?` — nil when the user has nudged the bands off a preset ("Custom" badge in the UI).
  - `bandBinding(at:)` returns a manual `Binding<Float>` so SwiftUI two-way bindings work for `$bands[i]` (iOS 17 SwiftUI doesn't expand `$store.bands[i]` to a working binding out of the box).
  - `bands.didSet` clears `currentPresetID` — cheap in-memory write, lets the UI switch the "active preset" chip highlight to "Custom" automatically.
  - `apply(preset:)` snaps to a stored preset (pads short / trims long arrays defensively, never crashing the AV engine).
  - `reset()` zeros bands but leaves `isEnabled` in place.
- **`AudioEngine` runtime EQ mirror** — added `lastAppliedBands` cache (defaults to all zero), `setEQEnabled(_:)` public method (re-applies from cache on enable, calls `EQController.bypass(eq)` on disable), private `applyEQ(bands:)` (clamps gains to ±12 dB and writes to the cached unit). Cache stays populated across bypass cycles so the user's tuning survives a temporary off-on toggle.
- **`EqualizerView`** (`Lunar/Sources/Settings/EqualizerView.swift`) — NEW Settings destination. Four sections: **Master On/Off** + **Bands** (10 vertical sliders) + **Presets** (horizontal scrolling row of `@Query` chips) + **Reset to Flat**. Vertical sliders are native `Slider`s rotated -90° with `.frame(width: 160, height: 28)` to swap dimensions back. Footer copy explains the centre-line / step granularity. Custom badge appears when the user has tweaked off a preset.
- **`LunarApp` + `LunarAppCoordinator`** — new `@State eqSettings = EQSettings()` is injected into the SwiftUI environment. `LunarAppCoordinator.task` does the once-only mirror at launch (warm-up `Task { await audioEngine.send(.setEQ(bands: initialBands)) }` + `audioEngine.setEQEnabled(eqSettings.isEnabled)`). `.onChange(of: eqSettings.bands)` + `.onChange(of: eqSettings.isEnabled)` keep the engine in sync live.
- **`Settings ▸ Equalizer`** row now points at the real `EqualizerView()` (previously the empty stub).

### Step 5 — Tier 2 Part 3: Playback Settings (crossfade + gapless)

- **`PlaybackSettings`** (`Lunar/Sources/Core/Audio/PlaybackSettings.swift`) — NEW `@MainActor @Observable final class`. Two stored values with `didSet` persistence + `onChange` callback broadcast:
  - `crossfadeDurationSeconds` (Double) — clamp-ranged `0.0…12.0`, snapped to a `0.5 s` step. Defaults to **6.0** (the prior hardcoded constant).
  - `gaplessEnabled` (Bool) — defaults to **true**.
  Both keys read on `init` from `UserDefaults` so a relaunch restores the user's choice. The static `clamp(_:)` helper is shared by the init restore + the public `updateCrossfade(seconds:)` mutator.
- **`AudioEngine.swift` runtime mirror** — replaced `private let crossfadeDurationSeconds = 6` with `var crossfadeDurationSeconds: Double = 6` (publicly readable for tests). Added `var gaplessEnabled: Bool`. `next()` now branches:
  - `gaplessEnabled == true` — `crossfade(...)` path with the user's slider duration. **0 s** = instant swap.
  - `gaplessEnabled == false` — `.load(_)` + `play()` path so a brief silence separates songs.
  `rampCrossfade(over:)` now short-circuits for `duration ≤ 0`: sets `outgoing.volume = 0 / incoming.volume = 1`, calls `outgoing.stop()`, returns — no divide-by-zero in `elapsed / duration` math.
- **`LunarAppCoordinator` wiring** — `task` block now takes `PlaybackSettings` and (a) pushes stored values into `audioEngine.crossfadeDurationSeconds` / `gaplessEnabled` once at launch, then (b) installs a `[weak audioEngine]` closure as `playbackSettings.onChange` so future slider / toggle edits propagate to the live engine in the same MainActor run-loop.
- **`LunarApp.swift`** — new `@State private var playbackSettings = PlaybackSettings()`. Injected into the view environment alongside `audioEngine`, `sleepTimer`, `playerTheme`, `appThemeSettings`.
- **`FakeAudioEngine.swift`** — added `var crossfadeDurationSeconds: Double = 6` + `var gaplessEnabled: Bool = true` so future tests can drive the same settings surface without instantiating real `AVAudioEngine`.
- **`PlaybackSettingsView`** (`Lunar/Sources/Settings/PlaybackSettingsView.swift`) — NEW (`Form`-style Settings page). Three sections:
  1. **Crossfade** — custom `CrossfadeSliderRow` (Title + live `Off / 3.5 s / 12.0 s` label bound to the slider, range `0…12`, step `0.5`). App accent tint on the slider.
  2. **Continuity** — `Toggle` for **Gapless Playback**, with a footer that switches between two pieces of explanatory text depending on the toggle's state.
  3. **Current** — summary chip that resolves to one of **Pure gapless · X.X s**, **Gapless crossfade · X.X s**, or **Cut transition · X.X s** so the user always sees the effective behaviour.
- **`SettingsView.swift`** — replaced the `playbackStub` placeholder with the real **Playback Setting** destination. `Settings` now leads the user into a fully wired Form.
- **`PlaybackSettingsTests`** (`Tests/LunarTests/PlaybackSettingsTests.swift`) — 13 tests covering: defaults (`6.0 s` + gapless on), the locked constants, clamp between 0 and 12, half-second snap, restoration of stored values (including the 0-value edge that would otherwise alias as "missing key"), persistence-on-write, didSet `onChange` firing once per write, and the `updateCrossfade` mutator going through `clamp`.

### Step 5 — Tier 2 Part 2: Sleep Timer UI in Now Playing + Settings

- **`SleepTimer.isActive`** (`Lunar/Sources/Core/Audio/SleepTimer.swift`) — new computed property `var isActive: Bool { secondsRemaining > 0 }`. Single source of truth for the "timer is running" check; replaces fragile "durationMinutes > 0" inference from views.
- **`SleepTimer` test-only hatch** — `#if DEBUG` extension exposes `_debugStart(seconds:)` so `SleepTimerTests` can drive a 1-second countdown for deterministic verification of the ticker + `onExpire` callback. Stripped from Release builds.
- **`SleepTimerSheet`** (`Lunar/Sources/Features/NowPlaying/SleepTimerSheet.swift`) — new sheet-style picker: 56pt status panel (moon SF Symbol + countdown or "Off" headline) above a 3-column pill grid (Off / 5 / 15 / 30 / 45 / 60 min). Active pill uses the player-theme accent fill. Selecting dims the sheet in 180ms then dismisses. `presentationDetents([.medium, .large])` for flexible heights. Reads `SleepTimer` + `PlayerThemeManager` from the environment so the chips tint match whichever player theme is active.
- **`SleepTimerChip`** inside `NowPlayingView` — pill-shaped button in the top chrome (right of the dismiss arrow). Renders the moon SF Symbol plus a monospaced `m:ss` countdown while the timer is active; collapses to just the icon when off. Capsule background reads `palette.railBackground`, foreground reads `palette.accent` (active) or `palette.primaryText` (off). Tapping opens the same `SleepTimerSheet`.
- **`NowPlayingView` rewrite** — top chrome HStack now hosts [dismiss · spacer · SleepTimerChip · queue-counter]. `.sheet(isPresented: $presentingSleepSheet)` modifier presents `SleepTimerSheet` above the fullScreenCover so dismissing Now Playing tears down the sheet correctly.
- **`SettingsView ▸ Sleep Timer` row** — Button-styled row between **App Theme** and **Equalizer**. Trailing shows "Off" / "5 min" / etc. Tracking the live `SleepTimer.durationMinutes`. Tapping toggles `presentingSleepSheet` so the same SleepTimerSheet opens — visual parity with the Now Playing moon chip.
- **`SleepTimerTests`** (`Tests/LunarTests/SleepTimerTests.swift`) — 11 tests covering: `isActive` invariants; UserDefaults restore on init; `select(Five)` / `select(0)` / `select(same)` semantics; `cancel` keeps the user's choice but resets the countdown; ticker decrements + fires `onExpire` after a 1-second `_debugStart`; cancelled ticker does NOT fire `onExpire`.

### Step 5 — Tier 1: Import → Local Files + ID3 / iTunes / Vorbis extraction

- **`AudioMetadataExtractor`** (`Lunar/Sources/Core/Library/AudioMetadataExtractor.swift`) — nonisolated `AVAsset.load` helper. Reads title / artist / album / track number / year (`commonKeyCreationDate`) / duration / bitrate (`AVAssetTrack.estimatedDataRate`) / sample rate / bit depth (`AudioStreamBasicDescription.mBitsPerChannel`) + embedded artwork (`AVMetadataItem.dataValue` — handles MP4 iTunes-artwork `NSDictionary` wraps transparently). Returns a `Sendable` `ImportedTrackPayload`. All values fall back to `nil` or a sensible placeholder (file stem → title, `Unknown Artist`) when tags are absent.
- **`MusicImporter`** (`Lunar/Sources/Core/Library/MusicImporter.swift`) — `@MainActor` orchestrator with one public entry `importFiles(at:)`. Pipeline: prefetch dedup set + Artist / Album caches (one round trip) → for each picked URL: `startAccessingSecurityScopedResource()` · copy bytes under a UUID-prefixed name on a detached `Task.detached(userInitiated)` · `await AudioMetadataExtractor.extract` · hop to main actor · dedup-check · find-or-create Artist + Album with first-track-wins artwork · insert Song · one global `context.save()`. Duplicate detection on `(title, artist, album, ⌊duration⌋)` for tagged files, `(originalFilename, fileSize)` for tag-less WAVs. Duplicates have their orphan copy removed from disk.
- **`ImportView` rewrite** (`Lunar/Sources/Features/Import/ImportView.swift`) — SwiftUI `.fileImporter(contentTypes: [.audio], allowsMultipleSelection: true)` opens the system document picker (Local Files · iCloud Drive · On My iPhone · third-party Files providers). Layout when empty: `EmptyState` with `square.and.arrow.down.on.square` SF Symbol + `Import Audio Files` purple capsule CTA. Layout with content: hero card · `Imported Today` (most recent batch, filtered by `lastImportIDs: [PersistentIdentifier]`) · `All Library` (top 20 songs by `dateAdded` desc) · tap-to-play rows. Full Now-Playing cover + Mini-Player dock wired through a shared `@State presentingNowPlaying` so the Mini-Player tap and the cover share one binding.
- **`MusicLibrary._rootDirectoryOverride`** (`Lunar/Sources/Core/Library/MusicLibrary.swift`) — internal mutable static (`nonisolated(unsafe)`) used by `MusicImporterTests` to redirect the destination dir to a per-test temp folder without polluting the real Application Support sandbox.
- **`MusicImporterTests`** (`Tests/LunarTests/MusicImporterTests.swift`) — 4 tests covering: single WAV import (verifies Song row + physical copy + UUID-prefixed `fileName`); re-import dedup (second pick skipped, library holds exactly one row); multi-unique WAV batch (3 inserted, 0 skipped); unreadable bytes path (extraction either inserts with zero-metadata fallback or is reported as failure without state corruption). Synthetic WAV writer emits a 1-second 44100 Hz mono 16-bit PCM silence WAV via direct RIFF / WAVE / `fmt ` / `data` chunk construction.

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
