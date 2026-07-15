import Foundation

/// Pure-Swift, dependency-free search helper for the Library's "Songs"
/// tab. Lives in `Core/Library` so it can be `@testable`-imported from
/// `Tests/LunarTests` without dragging in SwiftUI.
///
/// ## Why a static helper (not a SwiftPredicate `localizedStandardContains`)?
///
/// iOS 17 `SwiftData #Predicate` + `localizedStandardContains` has a
/// history of compiler edge-cases around diacritic-insensitive matching.
/// For library sizes Lunar ships with (typical < 1 000 songs), the
/// in-memory `.filter` approach taken here is instantaneous and gives
/// us full control over which fields contribute to the match.
/// `LibraryView` passes a debounced (250 ms) search string into the
/// subview; this helper makes the actual filter decision so it is
/// trivially testable without a SwiftUI host.
enum SongSearch {

    /// Filter `songs` against `query`. Empty/whitespace `query` returns
    /// the input array unchanged (the caller treats `query.isEmpty` as
    /// "show everything"). Matching is case-insensitive diacritic-
    /// insensitive via `localizedLowercase`.
    ///
    /// Fields searched, in priority order:
    /// 1. `title`
    /// 2. `artist`
    /// 3. `albumTitle` (optional)
    ///
    /// Trimmed whitespace on the query so `"  creep  "` doesn't blank
    /// out the result.
    static func filter(_ songs: [Song], by query: String) -> [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return songs }
        let needle = trimmed.localizedLowercase
        return songs.filter { song in
            if song.title.localizedLowercase.contains(needle) { return true }
            if song.artist.localizedLowercase.contains(needle) { return true }
            if let album = song.albumTitle?.localizedLowercase,
               album.contains(needle) {
                return true
            }
            return false
        }
    }
}
