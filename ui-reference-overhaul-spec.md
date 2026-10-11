# Lunar — UI Reference Overhaul + Compile-Fix Spec

> Status: drafted from 3 interview rounds (see `Decision log` at the bottom).
> No code is changed by this file. It exists so the implementation pass can be
> unambiguous and reviewer-friendly.

---

## 1. Goals

In priority order:

1. **Make `xcodebuild` succeed** for the Codemagic IPA pipeline (currently fails
   with **17 compile errors** in 3 files).
2. **Reshape the app's UI** to match the screenshots in `./Referance-Images/`
   (32 PNGs, `IMG_1254.PNG` – `IMG_1285.PNG`).
3. **Whole-app redesign** — take the images as ground truth, even if that means
   reverting or rewriting parts added in the recent `MeloPlayer overhaul`
   commits. Build new screens from scratch when the reference shows one that
   doesn't currently exist in code.
4. **Keep all current behavior** (sort, multi-select, debounced search, EQ,
   sleep timer, AirPlay, etc.) — re-binding UI elements is fine, but the
   underlying logic stays.
5. **Validation gate** is just a clean Codemagic-style iOS Release build
   (`xcodebuild ... clean build ... Release ... generic/platform=iOS ...`).
   XCTunit and snapshot tests are NOT part of the gate for this pass.

## 2. Non-goals

- No new third-party services, no SwiftData schema changes, no AVFoundation/iOS
  API additions.
- No XCUITest/snapshot infrastructure work (LunarSnapshotTests remains
  untouched).
- No custom image assets — use SF Symbols only.
- No XML/storyboard work — SwiftUI only.
- No refactor beyond what is required to keep the build green and the UI
  faithful to the reference.

## 3. Background

### 3.1 App map (current)

- **Tabs** (see `Lunar/Sources/App/AppTab.swift`):
  library, playlist, importer (Import), browse, settings.
- **Top-level chrome**: floating glass tab bar + floating mini-player
  (`RootView.swift`).
- **Design system** (`Lunar/Sources/DesignSystem/`):
  black canvas, lime/yellow-green accent (`#C7FF33` ≈ `0.78, 1.00, 0.20`),
  glass-card modifier with `.ultraThinMaterial`, MeloPlayer-style hero artwork.
- **Players / Now Playing stack**: `NowPlayingView` (full-screen cover from any
  tab), `MiniPlayer` (always above tab bar when something is loaded),
  `TransportRow`, `ScrubBar`, and a bouquet of small sheets (Sleep, Lyrics,
  PlaybackSpeed, RoutePicker, SongInfo, SelectMode).

### 3.2 Reference images (32 PNGs)

`./Referance-Images/IMG_1254.PNG … IMG_1285.PNG`. I'm unable to render PNGs in
the tool I work in, so the **per-image content has to be supplied by the user**
before the matching pass actually begins. Section 7 below records what was
inferred from the codebase so far and what still needs to be described.

### 3.3 Compile errors (the build-breakers)

All errors are the same root cause — `\\(...)` written in source where Swift
expects `\(...)`. Likely cause: text was authored in a context that treated
backslashes as escape characters, then pasted in. The 3 affected files are:

| File | Lines | Error kind |
| --- | --- | --- |
| `Lunar/Sources/Features/Import/ImportView.swift` | 9, 13, 134, 149 | `@Environment(\modelContext)` key-path + `\(recent.count)` interpolation |
| `Lunar/Sources/Features/Playlist/PlaylistView.swift` | 21, 173, 178, 187, 188 | `@Query` key-path + interpolation + nested `String(format: "%02d", ...)` where `"%02d"` was wrongly escaped and `%02d` made it into an integer literal |
| `Lunar/Sources/Features/Library/SelectModeSheet.swift` | 84 | Interpolation inside `Text("...song\(selectedIDs.count == 1 ? "" : "s")...")` |

> Build target: iOS 17.0, Xcode 26.4 (`iPhoneOS26.4.sdk`), configuration Release,
> arm64, `-whole-module-optimization`. CI is hosted on Codemagic.

## 4. Compile-fix plan (refactor-for-safety)

To prevent this from recurring, the three interpolation strings will be
rewritten using **plain string concatenation via local `let`s** rather than
nested `\( ... ? ... : ...)` ternaries inside format strings.

### 4.1 `Lunar/Sources/Features/Import/ImportView.swift`

- Lines 9 & 13: replace `@Environment(\modelContext)` and
  `@Query(sort: [SortDescriptor(\Song.dateAdded, order: .reverse)])`
  with their proper unescaped form.
- Lines 134 & 149 (`sectionHeader(title:, subtitle:)`): change two callers to
  build the `subtitle` argument with a local `let countWord = ... ? "song" :
  "songs"` and concatenate via `String` interpolation at the call site.
- No other logic change; `sectionHeader(title:subtitle:)` itself is unchanged.

### 4.2 `Lunar/Sources/Features/Playlist/PlaylistView.swift`

- Line 21: unescape `\.Playlist.dateCreated` key-path.
- Lines 173 & 178 (`detailSubtitle(for:)` and `subtitle(forSongs:)`): extract a
  private helper

  ```swift
  private func countWord(_ n: Int) -> String { n == 1 ? "song" : "songs" }
  ```

  and rewrite both functions as
  `"\(songs.count) \(countWord(songs.count)) | \(formatTotal(total))"`.
- Lines 187 & 188 (`formatTotal(_:)`): rewrite to use a single
  `String(format: "%d:%02d:%02d", h, m, s)` and a branch for the no-hours case
  with `String(format: "%d:%02d", m, s)` — avoids the `\(String(format:
  "%02d", ...))` anti-pattern entirely. The `%02d` literal lives inside a
  format string that is itself a string literal, so no escaping is needed
  there once the surrounding `\\(...)` is removed.

### 4.3 `Lunar/Sources/Features/Library/SelectModeSheet.swift`

- Line 84: rewrite the alert message using the same `countWord`-style helper or
  inline concatenation that produces `"song"` / `"songs"` without nesting a
  ternary inside a string interpolation.

### 4.4 Acceptance for the compile pass

- `xcodebuild -project Lunar.xcodeproj -scheme Lunar -configuration Release
  -destination generic/platform=iOS -sdk iphoneos CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CODE_SIGNING_ENTITLEMENTS=
  clean build` exits 0.
- No warnings added beyond what is already present in the trunk build.
- No behavioural change observable in the running app (same string output).

## 5. UI overhaul plan

### 5.1 Visual / design rules (locked)

- Keep `ColorTokens.canvas = .black` black background.
- Keep `ColorTokens.appAccent` lime/yellow-green `#C7FF33` for primary
  accents (selected tab, primary buttons, timeline accents). NO changes to
  accent color tokens.
- Keep `.ultraThinMaterial` glass card / floating chrome — same approach as
  current `LiquidGlassModifier`.
- Use **SF Symbols only** for icons. No new asset catalog entries. No custom
  PNG / SVG icons.
- Match structure / layout / component feel **best-effort** vs. the reference
  PNGs. Pixel-exact is not required. Hierarchy, contrast, balance and motion
  ARE required.
- Preserve core logic: re-binding buttons/swipes is allowed but no feature is
  dropped just because the new visual moves it elsewhere.
- Preserve all current sheets, alerts, fullScreenCovers, and
  navigationDestinations — they stay wired but their hosting views may be
  repositioned.

### 5.2 Token additions (if needed)

If the reference images reveal gaps, the **only** acceptable token changes are:

- Adding **new** members to `ColorTokens`, `Spacing`, or `Typography` —
  never editing existing values.
- Adding **new** modifiers / view-modifier helpers under
  `Lunar/Sources/DesignSystem/`. Keep them `private` to the file unless
  reused by 2+ views.

Examples that would be acceptable if the reference calls for it:

```swift
// Spacing.swift additions
static let tileCornerRadius: CGFloat = 22
static let rowVerticalInset:   CGFloat = 10

// Typography.swift additions
static let monoCaptionSmall = Font.system(size: 11, weight: .medium,
                                          design: .monospaced)
```

Avoid changing `ColorTokens.appAccent` because every screen already binds to
it; changing it would force a view-wide diff and risks double-bookkeeping
with the `PlayerThemePalette` overrides.

### 5.3 Screen-by-screen inventory (current → planned)

| Source screen | Current file | Status | Notes |
| --- | --- | --- | --- |
| Root / Floating tab bar / Mini player | `Lunar/Sources/App/RootView.swift`, `Features/Common/MiniPlayer.swift` | Restyle only | layout, glass feel, mini-player geometry may change |
| Library (Songs / Artists / Albums / Source tabs) | `Features/Library/LibraryView.swift` + siblings | Restyle only | header buttons, tab strip, list rows |
| Music Import (full tab) | `Features/Import/ImportView.swift` | Restyle only | hero card, imported-today list, all-library list |
| Playlist (landing) | `Features/Playlist/PlaylistView.swift` | Restyle only | smart-tile row, "Create new" row, playlist rows |
| Playlist detail | `Features/Playlist/PlaylistDetailView.swift` | Restyle only | hero card + song rows |
| Album row / detail | `Library/AlbumRow.swift`, `Library/AlbumDetailView.swift` | Restyle only | |
| Artist row / detail | `Library/ArtistRow.swift`, `Library/ArtistDetailView.swift` | Restyle only | |
| Song row | `Library/SongRow.swift` | Restyle only | |
| Sources tab | `Library/SourceView.swift` | Restyle only | |
| Sort menu | `Library/SortMenu.swift` | Restyle only | sheet |
| Select-mode sheet | `Library/SelectModeSheet.swift` | Restyle only | checklist rows + bottom action bar |
| Song info sheet | `Library/SongInfoSheet.swift` | Restyle only | sheet |
| Browse | `Features/Browse/BrowseView.swift` | Restyle only | |
| Settings landing | `Features/Settings/SettingsView.swift` | Restyle only | |
| Equalizer | `Settings/EqualizerView.swift` | Restyle only | |
| Playback settings | `Settings/PlaybackSettingsView.swift` | Restyle only | |
| Player style | `Settings/PlayerStyleView.swift` | Restyle only | theme tiles |
| App theme | `Settings/AppThemeView.swift` | Restyle only | |
| About | `Settings/AboutView.swift` | Restyle only | |
| Now Playing | `Features/NowPlaying/NowPlayingView.swift` + chips | Restyle only | |
| Lyrics view | `Features/NowPlaying/LyricsView.swift` | Restyle only | sheet |
| Sleep timer sheet | `Features/NowPlaying/SleepTimerSheet.swift` | Restyle only | sheet |
| Playback speed sheet | `Features/NowPlaying/PlaybackSpeedSheet.swift` | Restyle only | sheet |
| Route picker sheet | `Features/NowPlaying/RoutePickerSheet.swift` | Restyle only | sheet |
| AirPlay route button | `Features/NowPlaying/AirPlayRouteButton.swift` | Restyle only | chip |
| Smart playlist tile | `Playlist/SmartPlaylistTile.swift` | Restyle only | tile |
| Local playlist row | `Playlist/LocalPlaylistRow.swift` | Restyle only | |
| Scrub bar / Transport row | `NowPlaying/ScrubBar.swift`, `TransportRow.swift` | Restyle only | |
| Empty state | `Common/EmptyState.swift` | Restyle only (touched via caller) | |

### 5.4 New screens (built from scratch if image calls for it)

If a PNG shows a screen or modal that has no current source, create a new
SwiftUI view under `Lunar/Sources/Features/<FeatureArea>/` and wire it in:

- Add a tab case to `AppTab` only if the reference image shows a brand-new
  bottom-tab that the current 5 tabs don't have (`library, playlist,
  importer, browse, settings`).
- Otherwise, prefer sheet / cover / navigationDestination over adding tabs
  to keep the Luna surface area small.

### 5.5 Implementation order (proposed)

1. Compile fixes (Section 4) — smallest possible diff, done first so the
   build is green before any visual work.
2. `DesignSystem/` token additions only (if any — added means usage elsewhere
   in this same PR).
3. `Common/` shared atoms (`EmptyState`, `MiniPlayer`, modifiers) — these
   ripple into every tab.
4. Tab-level screens, one at a time, in the order: **Library → Import →
   Playlist → Browse → Settings**. Inspect each PNG that maps to that tab,
   make identifiers / file-tree changes, then the tab's children
   (Album/Artist/Source/SongInfo/Sort/Select).
5. `NowPlaying` stack last because it’s a full-screen cover that consumers
   tap into from the mini-player or any song row. Re-doing it last means
   callbacks / sheets aren't fighting in-flight changes in the tabs.

Each step ends with a `xcodebuild` clean build. Don't move on until it’s
green.

## 6. File-by-file action list (planned diff)

> All edits are **planned** — no code has been changed when this file is
> committed.

### 6.1 Compile fixes (must-do, smallest diff)

- `Lunar/Sources/Features/Import/ImportView.swift`
  - Lines 9, 13: unescape `\` keys.
  - Lines 134, 149: call a new private func (`songCountLabel(for: Int) ->
    String`) with concatenated output instead of nested-in-interpolation
    ternary.
- `Lunar/Sources/Features/Playlist/PlaylistView.swift`
  - Line 21: unescape `\` key.
  - Lines 173, 178: introduce `countWord(_ n: Int) -> String`; rewrite
    `subtitle(forSongs:)` and `detailSubtitle(for:)` as plain
    `"...\(n) \(countWord(n)) | \(formatTotal(t))"`.
  - Lines 187–188: rewrite `formatTotal(_:)` using a single `String(format:)`
    call per branch (no nested `\(String(format:))`).
- `Lunar/Sources/Features/Library/SelectModeSheet.swift`
  - Line 84: same picture — use a `songCountLabel(for:)` helper or local
    variable concatenation.

### 6.2 UI restyle (size varies; structure-preserving)

For each row in §5.3:

- Recompose layout to match the corresponding PNG (as best-effort per
  Section 5.1).
- Re-bind any gestures if the image shows a different control (swipe vs
  tap).
- Preserve the public surface of the view: `(view).body`, sub-views that
  tabs/library/sheets depend on, and any `@MainActor struct` symbols named
  in `Views` callers stay — only their internals change.

### 6.3 Cleanup (small)

- Delete `Lunar/Sources/nul` (looks like stray Windows `nul` character;
  not a Swift file).
- Delete `.freebuff/desktop.db*` — local Freebuff CLI cache, untracked,
  unrelated to the build.
- Add an entry to `CHANGELOG.md` for "UI reference overhaul + compile
  fixes".

## 7. Reference-image mapping — **NEEDS USER INPUT**

I cannot view PNGs in my tool. Before implementation begins, please map each
PNG to a current or new screen. Fill in this table (suggested format) and
attach to this spec:

| PNG | Target screen (existing / new) | Notes / sub-screens shown |
| --- | --- | --- |
| `IMG_1254.PNG` | _TBD_ | _TBD_ |
| `IMG_1255.PNG` | _TBD_ | _TBD_ |
| … | … | … |
| `IMG_1285.PNG` | _TBD_ | _TBD_ |

If mapping PNGs in chat feels too tedious, the lightest fallback is:

> "Each PNG corresponds, in order, to: Library → Library/Songs → Library/Artists
> → Library/Albums → Library/Source → Import → Playlist → Playlist (smart
> tiles) → Playlist detail → Now Playing → Now Playing lyrics → Sleep timer
> → Playback speed → AirPlay → Settings → Equalizer → Player Style → App
> Theme → About → Select mode → …".

Either the table or the paragraph can be used as ground truth during the
implementation pass.

## 8. Validation (post-implementation)

Per the user's Round 3 answer, the only hard gate is:

```bash
xcodebuild \
  -project Lunar.xcodeproj \
  -scheme Lunar \
  -configuration Release \
  -destination generic/platform=iOS \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  CODE_SIGNING_ENTITLEMENTS= \
  clean build
```

- Exit 0.
- No new warning classes introduced vs. trunk.

Unit tests and snapshot tests are NOT part of the gate for this pass, but
shouldn't regress either.

## 9. Out of scope / explicit non-goals

- iPad-specific layouts (the app declares iPad as a target but the
  reference images are presumed iPhone-shaped; iPad behaviour inherits from
  current).
- Localization beyond the existing English text already in the project.
- Adding new tabs or nav structures that aren't visible in the reference
  images.
- Custom fonts or custom image assets.

## 10. Risks / mitigations

| Risk | Mitigation |
| --- | --- |
| Some PNG shows a screen with logic we don't have (e.g. a "discover" feed). | Build a stub view with sane placeholders, flag in code review. |
| Floating tab bar / mini-player change might cover tab content. | Keep bottom inset of 140 (current behavior) intact unless the image contradicts. |
| Player theme palette overrides could fight the lime-on-black rule. | Only modify `ColorTokens` for non-Now-Playing surfaces; leave `PlayerThemes.swift` palette alone. |
| Whole-app redesign churn could break tabs that haven't been redone. | Reorder per §5.5 — never edit a child view before its parent. |
| The escaped-backslash bug could recur if another file uses nested ternaries inside `\(...)`. | Add a one-line comment at top of each redone helper explaining why we avoid that pattern. |

## 11. Decision log (interview answers)

| Q | Answer |
| --- | --- |
| Approach to reference images? | Whole-app redesign. |
| Compile-fix scope? | Fix escapes + refactor for safety. |
| Top priority? | Both fixes and UI in one pass. |
| Visual style? | Keep lime-on-black exactly. |
| New screen handling? | Build from scratch where the image shows new screens. |
| Match strictness? | Best-effort — structure / vibe must match, pixels optional. |
| Asset strategy? | SF Symbols only. |
| Build validation? | Codemagic-style Release build only. |
| Existing logic? | Keep all, allow re-binding. |
| The `Lunar/Sources/nul` file? | Delete alongside `.freebuff/`. |
| Spec format? | Markdown sections + checklist. |

## 12. TODO checklist (for the implementation pass)

### Compile-fix

- [ ] Unescape `@Environment(\modelContext)` and `@Query(SortDescriptor(\…))`
      in `ImportView.swift`
- [ ] Unescape `@Query(SortDescriptor(\…))` in `PlaylistView.swift`
- [ ] Rewrite `ImportView.swift` "Imported Today" / "All Library" subtitles
      via concatenation
- [ ] Rewrite `PlaylistView.swift` `detailSubtitle(for:)` /
      `subtitle(forSongs:)` / `formatTotal(_:)` clean of escaped backslashes
      and nested `\(String(format:))` anti-pattern
- [ ] Rewrite `SelectModeSheet.swift` alert message body
- [ ] `xcodebuild ... clean build` exits 0 (compile-fix milestone)

### Reference-image mapping

- [ ] Receive per-image descriptions from user (Section 7 table filled)
- [ ] Decide which PNGs introduce net-new screens

### Common atoms

- [ ] Re-look at `EmptyState.swift`
- [ ] Re-look at `MiniPlayer.swift`
- [ ] Optionally extend `ColorTokens` / `Spacing` / `Typography`
- [ ] Optionally extend `glassCard(cornerRadius:)` modifier

### Tab restyling

- [ ] Library tab + Songs/Artists/Albums/Source/Sort/SongInfo/Select screens
- [ ] Import tab
- [ ] Playlist tab + smart tiles / local rows / CreateNew / detail
- [ ] Browse tab
- [ ] Settings tab + Equalizer / Playback / PlayerStyle / AppTheme / About
- [ ] Now Playing stack: NowPlayingView + chips + sheets
- [ ] Lyrics view
- [ ] Sleep timer / Playback speed / Route picker / AirPlay chip

### Cleanup

- [ ] Delete `Lunar/Sources/nul`
- [ ] Delete `.freebuff/desktop.db*`
- [ ] Add a `CHANGELOG.md` entry

### Validation

- [ ] Clean Codemagic IPA build exits 0
- [ ] No new warning lines vs. trunk
- [ ] Manual sanity check by re-running app from Xcode (omitted from gate)

---

**Implementation is NOT part of this spec.** Once this file is approved the
next message should kick off Section 4 (compile fixes) followed by Section 5
(UI restyling) in the order in §5.5.
