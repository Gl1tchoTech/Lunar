# 🌙 Lunar

> An elegant yet modern music player — built for iOS, ready for SideStore.

Lunar is a beautifully crafted music player designed to make listening feel as good as the music itself. Clean typography, fluid motion, and a focus on what's playing — not on the controls.

---

## ✨ What's inside

- **iOS 17+ SwiftUI** — no UIKit, no storyboards, no reactive glue
- **Local-first** — your music stays on your device (no cloud required)
- **6 Player Themes** — **Cyber Neon** by default, plus **Vinyl / Lime**, **Aurora**, **Vivid Ocean**, **Sepia Wood**, **Pastel Playful**
- **Real audio DSP** — 10-band `AVAudioUnitEQ` with 13 built-in presets + Custom, engine-driven crossfade, gapless playback
- **System hooks** — Lock Screen / Control Center Now Playing card, full remote command set, AirPlay picker
- **Synced lyrics** — manual `.lrc` file import (per-song), active-line auto-scroll, tap-to-seek
- **SwiftData library** — Songs, Albums, Artists, Playlists, Listen Events
- **Universal** — iPhone tab bar, iPad split view
- **SideStore-ready** — unsigned IPA build, sign on-device with your Apple ID

---

## 🎯 Platform targets

| Platform | Status |
|---|---|
| 🍎 **iOS 17+** (iPhone & iPad) | ✅ Primary |
| 🤖 **Android** | 📋 Planned |

---

## 🚀 Getting started

### 1. Generate the Xcode project

```bash
brew install xcodegen   # one-time
xcodegen generate
open Lunar.xcodeproj
```

Requires **macOS 14+** with **Xcode 15.4+**.

### 2. Build a Sideload-friendly unsigned IPA

```bash
bash Scripts/build-ipa.sh       # Release
# Output: build/Lunar.ipa
```

…or trigger the GitHub Action `.github/workflows/build-ipa.yml`.

### 3. Install on iPhone via SideStore

See **[`docs/SIDESTORE.md`](docs/SIDESTORE.md)** for the full workflow.

---

## 📐 Project layout

```
Lunar/
├── Sources/
│   ├── App/                       # LunarApp + RootView + AppTab
│   ├── DesignSystem/              # ColorTokens · Typography · Spacing · PlayerThemes
│   ├── Features/
│   │   ├── Common/                # EmptyState
│   │   ├── Library/
│   │   ├── Playlist/
│   │   ├── Import/
│   │   ├── Browse/
│   │   └── Settings/
│   └── Core/                      # (Step 2: SwiftData models + Audio engine)
└── Resources/
    └── Assets.xcassets            # AppIcon · AccentColor

Tests/
├── LunarTests/                    # XCTest unit tests
└── LunarSnapshotTests/            # Snapshot tests

Scripts/                           # Local build helpers
docs/                              # SIDESTORE.md · BUILD.md
.github/workflows/build-ipa.yml    # CI → unsigned IPA artifact
project.yml                        # XcodeGen
```

---

## 🎨 Player Themes

Defaults to **Cyber Neon**. Switchable in **Settings → Player Style**.

| Theme | Character |
|---|---|
| **Cyber Neon** *(default)* | Black canvas, neon pink + cyan accents, glitch outline chrome |
| Vinyl / Lime | Lime vinyl disc with rainbow concentric rings |
| Aurora | Blue → purple gradient backdrop |
| Vivid Ocean | Bright blue top-to-bottom gradient |
| Sepia Wood | Cream + brown wood-grain button controls |
| Pastel Playful | Pink → cyan gradient, multicolor 3D controls |

All themes share the same information architecture — only the visual chrome changes.

---

### ✅ Step 5 — Tier 3: System Hooks
- [x] **`NowPlayingCenterManager`** — bridges `AudioEngine` → `MPNowPlayingInfoCenter` (Lock Screen / Control Center) + registers `MPRemoteCommandCenter` handlers (play / pause / toggle / next / previous / skipForward 15 s / skipBackward 15 s / changePlaybackPosition) that forward to `engine.send(_:)`. Built-in artwork cache keyed by `PersistentIdentifier`.
- [x] **`AirPlayRouteButton`** — `UIViewRepresentable` over `AVRoutePickerView`, tinted to the active player-theme palette, dropped into the Now Playing top chrome.
- [x] **`AudioEngine.onStateChange` callback** — diffed (Equatable) notification fired from every state-mutating site (`play/pause/seek/load/crossfade/tickProgress/setMasterVolume`). 0.1 s progress ticks don't spam listeners.
- [x] **`NowPlayingCenterManagerTests`** — 7 tests covering artwork cache hit/miss, diff-skip, pre-attach no-op, detach clearing, attach idempotency, full info dict keys.

## 🛣 Roadmap

### ✅ Step 1 — Scaffold (`af3708a`)
- [x] Project scaffold (compile-ready) · XcodeGen
- [x] 5-tab shell · iPad split view · empty states
- [x] Design tokens & 6 Player Themes
- [x] SideStore unsigned-IPA workflow

### ✅ Step 2 — SwiftData foundation (`67705ef`)
- [x] **SwiftData models** (Song · Album · Artist · Playlist · ListenEvent · EQPreset)
- [x] **`ModelContainer` wired into `LunarApp` + first-launch seeding of 13 EQ presets**
- [x] **Model tests** — empty-store, init defaults, schema round-trip, relationships

### ✅ Step 3 — Core library + Audio engine + Library Songs tab (next push)
- [x] **`MusicLibrary`** — resolve relative `fileName` → sandbox URL + diagnostics
- [x] **`LibraryService`** — SwiftData mutation façade
- [x] **`AudioPlayerInterface`** protocol + `PlaybackCommand` / `PlaybackRequest`
- [x] **`AudioEngine`** — `AVAudioEngine` + frozen player-graph + 0.1 s progress + 60 Hz crossfade
- [x] **`EQController`** — 10-band ISO EQ with ±12 dB clamp
- [x] **`SleepTimer`** — 5 / 15 / 30 / 45 / 60 + Off (UserDefaults)
- [x] **`AppAudioSession`** — `.playback` category + interruption / route-change observers
- [x] **`LibraryView` Songs tab** — sort menu + shuffle / play pills + `@Query` rows + context menu + empty state
- [x] **`LibraryServiceTests`** (8) + **`AudioEngineControllerTests`** + `FakeAudioEngine` + `EQController` (9)

### ✅ Step 5 — Tier 2 Part 3: Playback Settings (`pending`)
- [ ] **Crossfade duration slider** — 0…12 s, snapped to 0.5 s. 0 = instant swap (gapless); ≥ 0.5 = classic overlap fade. Default 6 s.
- [ ] **Gapless Playback toggle** — when ON, the queue advance swaps the next song into the active node; when OFF, a brief silence separates songs. Default ON.
- [ ] **PlaybackSettingsView** (`Form` with Crossfade + Continuity + Current sections), replaces the Step-4 `StubPage`.
- [ ] **AudioEngine.next() branching** + `rampCrossfade` zero-duration guard + divide-by-zero defence.
- [ ] **LunarAppCoordinator wiring** pushes stored values into the live engine + mirrors `onChange` events.
- [ ] **`PlaybackSettingsTests`** — 13 tests on defaults, clamp, restoration, persistence, didSet+onChange.

### ✅ Step 5 — Tier 2 Part 2: Sleep Timer UI (`pending`)
- [ ] **Moon chip in Now Playing top chrome** — pill with countdown next to the dismiss arrow (Cyber Neon accent when active). Tapping opens the sheet.
- [ ] **SleepTimerSheet picker** — 3-column pill grid (Off / 5 / 15 / 30 / 45 / 60) with status panel + dismissible via swipe.
- [ ] **Settings ▸ Sleep Timer row** — same `SleepTimerSheet` as Now Playing, plus trailing value showing current duration.
- [ ] **SleepTimer.isActive computed** + `#if DEBUG` test hatch (`_debugStart(seconds:)`) + 11 `SleepTimerTests`.

### ✅ Step 4 — Feature wiring (next push)
- [x] **Library sub-tabs** — Artists (circular portraits), Albums (square covers), Source (yellow folder rows). Each row pushes an Album/Artist detail view.
- [x] **Now Playing full-screen cover** — Player-Theme gradient background, large artwork, title/artist, scrub bar, 5-button transport row (shuffle / prev / play-pause / next / repeat). Launched from Mini Player.
- [x] **Mini-player overlay** — pill docked above the tab bar on Library, Playlist, and Import. Hidden until a song plays. Tap → opens Now Playing.
- [x] **Playlist tab full rewrite** — `Most Played` / `Recently Played` gradient hero tiles, smart-playlist song counts from `Song.playCount` / `Song.lastPlayed`, `My Local Playlist (N)` count, big lime `+ Create New` alert, list of user playlist rows (with `My Favorites` heart glyph). Tap any tile / row → `PlaylistDetailView`.
- [x] **AudioEngine queue** — in-memory `[PlaybackRequest]`, `enqueueNext`, `playQueue`, `next()`, `previous()` walking the queue, automatic advance in `handleNextNodeCompleted`. Race-gate via `isTransitioning`.
- [x] **Settings polish** — `PlayerStyleView` (six theme preview cards, tap to apply), `AppThemeView` (System / Light / Dark segmented picker + 3×2 accent swatch grid persisted via `AppThemeSettings`). Equalizer / Playback / Language / About stay stub views for Step 5.

### ✅ Step 5 — Tier 4: Settings polish
- [x] **`AppMetadata`** — single source of truth for `version`, `build`, `bundleIdentifier`, `displayName`, `repositoryURL`, `copyrightYear`, plus a `versionAndBuild` format helper. Reads `CFBundleShortVersionString` / `CFBundleVersion` at runtime so a TestFlight bump shows up in About without touching Swift.
- [x] **`AboutView`** — Settings ▸ About, real destination. Version / Build / Bundle labels, Source-on-GitHub button + URL link, Credits (UI / Audio / Storage / Theme) section, `🌙 Lunar · © <year>` footer.
- [x] **SettingsView cleanup** — removed Language stub row + duplicate inline Version/Build/Made-with section (now in About). About row added between Settings section and the deliberate Feedback / Rate Us / Privacy stubs.
- [x] **`AppMetadataTests`** — 7 tests pinning the version+build format, repo URL host + path, bundle ID, copyright year.

### ⏭ Up next (Tier 5 → Tier 7)
- [ ] Tier 5 — Player UX polish: persist Shuffle + Repeat across relaunch, "My Favorites" smart playlist tile, Library search bar, full Song Info sheet
- [ ] Tier 6 — Import surface expansion: Other Apps handoff, branded Cloud Providers (Wi-Fi Drive explicitly deferred per user)
- [ ] Tier 7 — Browse downloader / streamer (placeholder today; user-deferred until they say otherwise)

### ✅ Closed: Step 5 Tier 2 system hooks
- [x] `MPNowPlayingInfoCenter` — title / artist / duration / elapsed / rate / media type pushed on every state change
- [x] `MPRemoteCommandCenter` — full standard transport set + 15 s skip + scrub-from-lock-screen
- [x] `AVRoutePickerView` — AirPlay / external-output pill in the Now Playing chrome
- [x] Artwork cache — `MPMediaItemArtwork` per song, lazily decoded from `Song.artwork` bytes, downscaled to 600 pt

### ✅ Closed: Step 5 Tier 2 settings (parts 1–5)
- [x] Sleep-timer UI in Now Playing + Settings (`Settings ▸ Sleep Timer`)
- [x] Playback Settings (crossfade + gapless, `Settings ▸ Playback Setting`)
- [x] Lyrics `.lrc` import (manual, per-song, `LyricsView` sheet)
- [x] Equalizer 10-band sliders (`Settings ▸ Equalizer`)
- [ ] Tier 2 — `"My Favorites"` smart playlist + Shuffle / Repeat state persistence
- [ ] Tier 3 — Search (Library) + Song Info sheet (rename / add to playlist / share / show in Finder)
- [ ] Tier 4 — Import surface expansion: Wi-Fi Drive · Other Apps · Cloud Providers
- [ ] Tier 4 — Browse downloader/streamer (placeholder today)
- [ ] Future — `PlaylistEntry` join entity for ordered playlists (drag-to-reorder)
- [ ] Future — Feedback / Rate Us / Privacy Policy destinations
- [ ] Future — Final QA + sideload test on a real iPhone

---

## 📄 License

TBD

---

*Crafted with care. Made for music lovers.*
