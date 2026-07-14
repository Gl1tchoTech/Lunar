# Changelog

All notable changes to **Lunar** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- SwiftData models for Song / Album / Artist / Playlist
- AVAudioEngine-based playback: real DSP, gapless, crossfade
- 10-band EQ with presets and reverb
- Lyrics (.lrc manual import)
- Sleep timer
- Smart playlists (Most Played, Recently Played)
- Now Playing screen + sheets
- Settings rows (Player Style · App Theme · Equalizer · Playback · Language · Import)

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
