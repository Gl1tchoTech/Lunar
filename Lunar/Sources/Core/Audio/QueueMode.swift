import Foundation

/// Whether the playback queue should be presented in random order.
///
/// **`.off`** — the queue walks in the order the caller passed to
/// `AudioEngine.playQueue(_:startIndex:)`. This is the launch default.
///
/// **`.on`** — the queue still starts at wherever `startIndex` pointed,
/// but every other song is shuffled (Apple Music behaviour). The
/// currently-playing song is **not** re-randomised — toggling shuffle
/// mid-play merely reshuffles the *upcoming* tail.
enum ShuffleMode: String, CaseIterable, Sendable, Codable {
    case off
    case on
}

/// Whether the playback queue should loop.
///
/// **`.off`** — End of queue pauses playback. (Default.)
///
/// **`.all`** — End of queue wraps back to index 0 and continues.
///
/// **`.one`** — End-of-current-song re-seeks that song to `0` and
/// continues playing it on the same node. (Apple Music behaviour —
/// equivalent to "Replay current song once, then check `.all`/`.off`").
enum RepeatMode: String, CaseIterable, Sendable, Codable {
    case off
    case all
    case one
}

extension RepeatMode {
    /// SF Symbol that visually conveys the mode. TransportRow uses
    /// this so the glyph itself communicates state.
    var systemImage: String {
        switch self {
        case .off:    "repeat"
        case .all:    "repeat.circle.fill"
        case .one:    "repeat.1.circle.fill"
        }
    }
}

extension ShuffleMode {
    /// SF Symbol visualising the mode. TransportRow uses this so the
    /// glyph + tint conveys state instead of a separate text label.
    var systemImage: String {
        switch self {
        case .off:    "shuffle"
        case .on:     "shuffle.circle.fill"
        }
    }
}
