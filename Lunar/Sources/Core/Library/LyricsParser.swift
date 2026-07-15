import Foundation

/// One timed line of lyrics.
///
/// **Time is stored in seconds** (converted from `[mm:ss(.xx)]` at
/// parse time) so the Now Playing UI can compute the active line via
/// binary search against `engine.state.currentTime`.
///
/// **Plain text** is kept exactly as written — we don't strip
/// diacritics, normalize whitespace, or detect duplicate lines.
struct LyricLine: Equatable, Hashable {
    let time: TimeInterval
    let text: String
}

/// Pure-Swift `.lrc` (LRC) parser.
///
/// ## LRC format reference
/// Each timed line looks like:
/// ```
/// [mm:ss(.xx)]lyric text here
/// ```
/// Lines with no leading `[mm:ss]` timestamp are **metadata** (artist,
/// title, album, `[al:...]`, `[ti:...]`) and ignored by the parser.
///
/// Multi-timestamp lines (one lyric shown at several times) like
/// ```
/// [00:12.50][00:48.20]chorus line
/// ```
/// are emitted as **separate `LyricLine` entries** — one per
/// timestamp — sharing the same trailing text.
///
/// Inline metadata like `[00:12.00]text[00:48.00]more` is rare but
/// supported: any `[\d+:\d+...]` between or after the line's leading
/// timestamps is treated as another timestamp.
enum LyricsParser {

    /// Parse raw LRC text into ordered `(time, text)` tuples.
    ///
    /// Empty input returns `[]`. Lines with no legible timestamp are
    /// skipped silently. The result is **sorted by `time`** so
    /// `LyricsNavigator.activeLine` can binary-search it.
    static func parse(_ text: String) -> [LyricLine] {
        guard !text.isEmpty else { return [] }

        // Strip BOM if present (text editors on Windows love adding them).
        let cleaned = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text

        // Tolerate CRLF, CR, and LF line endings (split on any).
        let rawLines = cleaned.split(
            whereSeparator: { $0 == "\n" || $0 == "\r" }
        )

        var lines: [LyricLine] = []
        lines.reserveCapacity(rawLines.count)

        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip pure metadata blocks (no leading timestamp).
            // "[ti:Title]\n[ar:Artist]\n...": each line starts with `[id:`.
            if isMetadata(trimmed) { continue }

            // Collect all leading timestamps on the line plus optional
            // additional timestamps between the text. We walk char-by-char
            // looking for `[mm:ss(.xx)]` segments.
            let segments = extractTimestamps(in: trimmed)
            if segments.timestamps.isEmpty { continue }

            for stamp in segments.timestamps {
                lines.append(LyricLine(time: stamp, text: segments.text))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    // MARK: - Internals

    /// Returns every `mm:ss(.xx)` timestamp found as a `[…]` tag at the
    /// beginning of the line OR interspersed in the text, alongside the
    /// last text segment after the final timestamp. Anything before the
    /// first timestamp tag (e.g. whitespace) is dropped.
    private static func extractTimestamps(in line: String) -> (timestamps: [TimeInterval], text: String) {
        var stamps: [TimeInterval] = []
        var working = Substring(line)
        var trailing = ""

        while let open = working.firstIndex(of: "[") {
            guard let close = working[open...].firstIndex(of: "]") else { break }
            let inside = working[working.index(after: open)..<close]
            if let parsed = parseTimestamp(String(inside)) {
                stamps.append(parsed)
                // Move past this tag.
                working = working[working.index(after: close)...]
            } else {
                // `[...]` is a real tag we can't parse as a timestamp;
                // bail out — anything after is text.
                if stamps.isEmpty {
                    // Leading tag wasn't a timestamp at all → metadata line.
                    return ([], "")
                }
                trailing = String(working[working.index(after: close)...])
                break
            }
        }
        if trailing.isEmpty {
            trailing = String(working)
        }
        return (stamps, trailing.trimmingCharacters(in: .whitespaces))
    }

    /// Recognises a `[mm:ss(.xx)]`-shaped tag and returns the absolute
    /// seconds. Returns `nil` for malformed input (anything outside
    /// the format) and for anything that doesn't START with digits —
    /// e.g. `[ti:Title]` or `[ar:Artist]`.
    ///
    /// **Implementation note:** We `scanDouble` for the seconds field
    /// *after* the colon rather than splitting off a separate decimal
    /// scan. Splitting into `scanInt(seconds)` + `scanString(".")` +
    /// `scanDouble(fraction)` would interpret `"50"` (the fraction
    /// part of `"00:12.50"`) as `50.0`, not `0.5`. Letting
    /// `scanDouble` consume both whole and fractional seconds lets the
    /// scanner's own decimal handling produce the right value.
    private static func parseTimestamp(_ raw: String) -> TimeInterval? {
        // Strict prefix matching: `\d{1,2}:\d{1,2}(\.\d{1,3})?`.
        // `[ti:Title]` etc. fail because the first char isn't a digit.
        let scanner = Scanner(string: raw)
        var minutes: Double = 0
        guard scanner.scanDouble(&minutes), minutes >= 0 else { return nil }
        // Next char must be ':' (preserved through the double scan).
        guard scanner.scanString(":") != nil else { return nil }
        // Scan seconds + optional `.xx(x)` as a single double so a
        // value like `"12.50"` produces `12.5` (not `12 + 50 == 62`).
        var seconds: Double = 0
        guard scanner.scanDouble(&seconds), seconds >= 0, seconds < 60 else { return nil }
        return Double(minutes) * 60 + seconds
    }

    /// Quick metadata-line detection: starts with `[` then a non-digit
    /// character (e.g. `[ti:` `[ar:` `[al:` `[by:` `[offset:`).
    /// Lines like `[00:12]text` won't match because the char after `[`
    /// is a digit.
    private static func isMetadata(_ line: String) -> Bool {
        guard line.hasPrefix("[") else { return false }
        let afterBracket = line.index(after: line.startIndex)
        guard afterBracket < line.endIndex else { return false }
        let first = line[afterBracket]
        return !first.isNumber && first != "]"
    }
}
