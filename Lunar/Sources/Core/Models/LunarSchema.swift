import Foundation
import SwiftData

// MARK: — LunarSchema

/// Centralised list of every `@Model` in Lunar. Used by `LunarApp`
/// to build the `ModelContainer`, and by preview / test helpers to
/// seed in-memory containers.
enum LunarSchema {

    static let models: [any PersistentModel.Type] = [
        Song.self,
        Album.self,
        Artist.self,
        Playlist.self,
        ListenEvent.self,
        EQPreset.self,
    ]

    static let schema = Schema(models)
}

// MARK: — BuiltInEQPresets

/// Factory EQ presets seeded on first launch only. The library
/// (`Song` / `Playlist`) stays **empty** per the design brief.
///
/// **Important**: This is a **computed property**, not a `static let`,
/// because `@Model` instances become bound to the `ModelContext` that
/// first touches them. If we held a single shared array as `static let`,
/// the App launch would seed those instances into its real container
/// and any later context (tests, previews) would fatal-error when
/// trying to re-insert the same instances. Computing fresh objects
/// per call avoids that trap.
enum BuiltInEQPresets {

    static let referenceDate = Date(timeIntervalSince1970: 0)

    static var presets: [EQPreset] { [
        EQPreset(name: "Flat",
                 isBuiltIn: true,
                 bands: Array(repeating: 0, count: 10),
                 dateCreated: referenceDate),

        EQPreset(name: "Acoustic",
                 isBuiltIn: true,
                 bands: [  4,  3,  2,  1,  0,  1,  2,  2,  3,  4 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Bass Booster",
                 isBuiltIn: true,
                 bands: [  6,  5,  4,  3,  1,  0,  0,  0,  0,  1 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Bass Reducer",
                 isBuiltIn: true,
                 bands: [ -6, -5, -4, -2,  0,  1,  2,  3,  3,  3 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Classical",
                 isBuiltIn: true,
                 bands: [  4,  3,  2,  1, -1, -1,  0,  2,  3,  4 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Dance",
                 isBuiltIn: true,
                 bands: [  5,  4,  2,  0, -1, -1,  0,  2,  4,  5 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Electronic",
                 isBuiltIn: true,
                 bands: [  4,  3,  1,  0, -2,  1,  0,  1,  3,  5 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Hip-Hop",
                 isBuiltIn: true,
                 bands: [  5,  4,  2,  1, -1, -1,  1,  1,  2,  3 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Jazz",
                 isBuiltIn: true,
                 bands: [  3,  2,  1,  2, -1, -1,  0,  1,  2,  3 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Pop",
                 isBuiltIn: true,
                 bands: [  2,  5,  4,  1, -1, -1,  1,  0,  2,  3 ],
                 dateCreated: referenceDate),

        EQPreset(name: "R&B",
                 isBuiltIn: true,
                 bands: [  3,  7,  6,  1, -2, -1,  2,  2,  3,  4 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Rock",
                 isBuiltIn: true,
                 bands: [  5,  4,  3,  1, -1, -1,  0,  2,  3,  4 ],
                 dateCreated: referenceDate),

        EQPreset(name: "Vocal Booster",
                 isBuiltIn: true,
                 bands: [ -2, -1,  0,  3,  5,  5,  3,  0, -1, -2 ],
                 dateCreated: referenceDate),
    ] }
}

// MARK: — Seed

/// First-launch seeding helper. Invoked from `RootView.task` on the
/// main context after the UI is mounted.
///
/// Library content (`Song` / `Album` / `Artist` / `Playlist`) stays
/// empty per the design brief — only factory EQ presets are seeded.
enum Seed {

    static func seedBuiltInPresetsIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<EQPreset>())) ?? 0
        guard existing == 0 else { return }

        for preset in BuiltInEQPresets.presets {
            context.insert(preset)
        }
        try? context.save()
    }
}
