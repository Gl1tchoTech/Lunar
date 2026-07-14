# 🌙 Building Lunar from source

Lunar is an iOS 17+ SwiftUI app. The Xcode project is **generated** from
`project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the
repo stays small and diff-friendly.

---

## Requirements

- **macOS 14+**
- **Xcode 15.4+** (Swift 5.10 / SwiftUI 5)
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — `brew install xcodegen`
- *(Optional)* [xcpretty](https://github.com/xcpretty/xcpretty) — `gem install xcpretty`

---

## Generate the Xcode project

```bash
xcodegen generate
# Output: Lunar.xcodeproj
open Lunar.xcodeproj
```

> The `.xcodeproj` directory is **gitignored** — never commit it. Always
> regenerate from `project.yml`.

---

## Build & run

1. In Xcode: select the **Lunar** scheme (left of ▶︎)
2. Choose destination: any **iPhone** simulator running iOS 17+ (e.g. *iPhone 15*)
3. Press **⌘R**

The app launches with all 5 tabs (Library · Playlist · Import · Browse · Settings),
each showing a polished "No music yet" empty state (or the Browse categories
grid, which is the placeholder for the future downloader/streamer).

The default Player Theme is **Cyber Neon** and the global App accent is
**Purple**, but every screen intentionally starts **empty** — no bundled songs.

---

## Run tests

```bash
xcodebuild test \
  -project Lunar.xcodeproj \
  -scheme Lunar \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

This runs both unit tests (`LunarTests`) and snapshot tests (`LunarSnapshotTests`).

---

## Build a Sideload-friendly unsigned IPA

```bash
bash Scripts/build-ipa.sh      # Release
ls build/Lunar.ipa
```

Then transfer `build/Lunar.ipa` to your iPhone and sideload via SideStore.
See [`docs/SIDESTORE.md`](SIDESTORE.md) for the full flow.

---

## Customize Player Themes

The 6 player themes live in `Lunar/Sources/DesignSystem/PlayerThemes.swift`.
**Cyber Neon** is the default. To change the default, edit
`PlayerThemeManager.init()` to seed a different `PlayerThemeID`.

---

## CI

The `.github/workflows/build-ipa.yml` workflow builds an unsigned IPA on
every push to `main` and on manual dispatch. Download the artifact under
the **Actions** tab.

---

## Project conventions

| Concern | Rule |
|---|---|
| **Colors** | Always pull from `ColorTokens` or a `PlayerThemePalette`. No raw hex inside feature code. |
| **Fonts** | Always use `Typography.<name>`. No `.font(.system(...))` outside the design system file. |
| **Spacing** | Always use `Spacing.<name>`. No magic numbers. |
| **Tabs / screens** | One file per top-level destination under `Features/`. Empty screens use `EmptyState`. |
| **Models** *(Step 2+)* | SwiftData `@Model` classes in `Core/Models/`. |
| **Audio** *(Step 2+)* | Wrapped by `AudioEngine` in `Core/Audio/`. No raw `AVAudioEngine` use from views. |

---

## Where is Android?

Not started. **iOS is the priority** per the design brief; Android will
arrive once the iOS app is feature-complete and stable.
