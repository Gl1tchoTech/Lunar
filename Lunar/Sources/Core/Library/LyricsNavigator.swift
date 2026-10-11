import Foundation

/// Pure-Swift helper that finds the active lyric line for a given playhead
/// time. Used by the Now Playing UI to highlight the current line.
enum LyricsNavigator {

    /// Returns the **index** of the last `LyricLine` whose `time` is
    /// less than or equal to `at`, or `nil` when there is no such line
    /// (empty input or `at` is before the first timestamp).
    static func activeLine(in lines: [LyricLine], at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        // `lines` is sorted ascending by `time` (see `LyricsParser.parse`).
        var candidate: Int? = nil
        for (idx, line) in lines.enumerated() {
            if line.timeValue <= time {
                candidate = idx
            } else {
                break
            }
        }
        return candidate
    }
}
