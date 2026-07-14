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

- [x] Project scaffold (compile-ready)
- [x] 5-tab shell + iPad split view + empty states
- [x] Design tokens & 6 Player Themes
- [x] SideStore unsigned-IPA workflow
- [x] **SwiftData models** (Song · Album · Artist · Playlist · ListenEvent · EQPreset)
- [x] **ModelContainer wired into `LunarApp` + first-launch seeding of 13 EQ presets**
- [x] **Model tests** — empty-store, init defaults, schema round-trip, relationships
- [ ] `MusicLibrary` helper (resolve relative `fileName` → sandbox URL)
- [ ] `LibraryService` façade for mutations (toggleFavorite, createPlaylist)
- [ ] `PlaylistEntry` join entity for ordered playlists (drag-to-reorder)
- [ ] AVAudioEngine + 10-band EQ + crossfade + sleep timer
- [ ] Library: Songs / Artists / Albums / Source tabs
- [ ] Sort menu + select mode + song menu
- [ ] Playlist tab + smart playlists + create flow
- [ ] Import: Local Files · Wi-Fi Drive · Cloud
- [ ] Browse: downloader/streamer (placeholder today)
- [ ] Settings: Player Style · App Theme · EQ · Playback · Language
- [ ] Now Playing + sheets (lyrics, playback speed, song info, song menu, AirPlay)
- [ ] Final QA + sideload test

---

## 📄 License

TBD

---

*Crafted with care. Made for music lovers.*
