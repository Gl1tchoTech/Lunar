# 🌙 Lunar

> An elegant yet modern music player — built for iOS, ready for SideStore.

Lunar is a beautifully crafted music player designed to make listening feel as good as the music itself. Clean typography, fluid motion, and a focus on what's playing — not on the controls.

---

## ✨ What's inside

- **iOS 17+ SwiftUI** — no UIKit, no storyboards, no reactive glue
- **Local-first** — your music stays on your device (no cloud required)
- **6 Player Themes** — **Cyber Neon** by default, plus **Vinyl / Lime**, **Aurora**, **Vivid Ocean**, **Sepia Wood**, **Pastel Playful**
- **Real audio DSP** — 10-band `AVAudioUnitEQ`, engine-driven crossfade, gapless playback
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

### ✅ Step 4 — Feature wiring (next push)
- [x] **Library sub-tabs** — Artists (circular portraits), Albums (square covers), Source (yellow folder rows). Each row pushes an Album/Artist detail view.
- [x] **Now Playing full-screen cover** — Player-Theme gradient background, large artwork, title/artist, scrub bar, 5-button transport row (shuffle / prev / play-pause / next / repeat). Launched from Mini Player.
- [x] **Mini-player overlay** — pill docked above the tab bar on Library, Playlist, and Import. Hidden until a song plays. Tap → opens Now Playing.
- [x] **Playlist tab full rewrite** — `Most Played` / `Recently Played` gradient hero tiles, smart-playlist song counts from `Song.playCount` / `Song.lastPlayed`, `My Local Playlist (N)` count, big lime `+ Create New` alert, list of user playlist rows (with `My Favorites` heart glyph). Tap any tile / row → `PlaylistDetailView`.
- [x] **AudioEngine queue** — in-memory `[PlaybackRequest]`, `enqueueNext`, `playQueue`, `next()`, `previous()` walking the queue, automatic advance in `handleNextNodeCompleted`. Race-gate via `isTransitioning`.
- [x] **Settings polish** — `PlayerStyleView` (six theme preview cards, tap to apply), `AppThemeView` (System / Light / Dark segmented picker + 3×2 accent swatch grid persisted via `AppThemeSettings`). Equalizer / Playback / Language / About stay stub views for Step 5.

### ⏭ Step 5 Tier 2 onwards
- [ ] Tier 2 — System hooks for "feels like a music player" (`MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` + `AVRoutePickerView`)
- [ ] Tier 2 — Settings polish (Sleep-timer UI + Playback Settings + Lyrics `.lrc` import + Equalizer 10-band sliders)
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
