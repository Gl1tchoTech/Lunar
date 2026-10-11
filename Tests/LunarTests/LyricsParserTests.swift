import XCTest
@testable import Lunar

/// Pure-Swift LRC parser tests.
///
/// **Critical regression case:** Prior versions of `parseTimestamp`
/// split the seconds field into `scanInt` + `scanString(".") +
/// scanDouble(fraction)`, which misinterpreted `"50"` (the fraction
/// of `"00:12.50"`) as `50.0` rather than `0.5` — producing a
/// timestamp of `62.0` seconds instead of `12.5`. The fix uses a
/// single `scanDouble` for the seconds+fraction. Tests below pin that
/// behaviour in place.
final class LyricsParserTests: XCTestCase {

    // MARK: - Empty / metadata input

    func test_parse_emptyString_returnsEmpty() {
        XCTAssertEqual(LyricsParser.parse(""), [])
    }

    func test_parse_blankLinesOnly_returnsEmpty() {
        XCTAssertEqual(
            LyricsParser.parse("\n   \n\n"),
            []
        )
    }

    func test_parse_pureMetadata_returnsEmpty() {
        let text = """
        [ti:Title]
        [ar:Artist]
        [al:Album]
        [by:LRC Author]
        [offset:0]
        """
        XCTAssertEqual(LyricsParser.parse(text), [])
    }

    func test_parse_ignoresMetadataLinesEvenWhenMixedWithLyrics() {
        let text = """
        [ti:My Song]
        [00:12.50]first line
        [ar:Some Artist]
        [00:24.00]second line
        """
        let result = LyricsParser.parse(text)
        XCTAssertEqual(result.count, 2, "metadata lines must be dropped")
        XCTAssertEqual(result[0].timeValue, 12.5, accuracy: 0.0001)
        XCTAssertEqual(result[0].text, "first line")
        XCTAssertEqual(result[1].timeValue, 24.0, accuracy: 0.0001)
    }

    // MARK: - Happy-path parsing

    func test_parse_singleLineWithWholeSeconds() {
        let result = LyricsParser.parse("[00:12]one line")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].timeValue, 12.0, accuracy: 0.0001)
        XCTAssertEqual(result[0].text, "one line")
    }

    func test_parse_multipleLinesAreSortedByTime() {
        let text = """
        [00:48.20]second
        [00:12.50]first
        [01:00.00]third
        """
        let result = LyricsParser.parse(text)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.timeValue), [12.5, 48.2, 60.0])
        XCTAssertEqual(result.map(\.text), ["first", "second", "third"])
    }

    func test_parse_dropsBlankTrailingText() {
        let result = LyricsParser.parse("[00:12]   ")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].timeValue, 12.0, accuracy: 0.0001)
        XCTAssertEqual(result[0].text, "")
    }

    // MARK: - REGRESSION: Fractional timestamps must NOT add whole seconds

    /// The headline bug. `"00:12.50"` must parse to 12.5 seconds —
    /// not 62.0 (which would happen if a `scanDouble` saw only `"50"`).
    func test_parse_fractionalTimestamp_doesNotDoubleParse() {
        let result = LyricsParser.parse("[00:12.50]lyric")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.timeValue, 12.5, accuracy: 0.0001)
        XCTAssertNotEqual(result.first?.timeValue, 62.0, accuracy: 0.0001)
    }

    func test_parse_oneDecimalPlace() {
        let result = LyricsParser.parse("[00:05.5]short fraction")
        XCTAssertEqual(result.first?.timeValue, 5.5, accuracy: 0.0001)
    }

    func test_parse_threeDecimalPlaces() {
        let result = LyricsParser.parse("[00:00.123]millis")
        XCTAssertEqual(result.first?.timeValue, 0.123, accuracy: 0.0001)
    }

    func test_parse_zeroSecondZeroFractionMinuteBoundary() {
        let result = LyricsParser.parse("[00:00.00]start")
        XCTAssertEqual(result.first?.timeValue, 0.0, accuracy: 0.0001)
    }

    func test_parse_oneMinuteBoundary() {
        let result = LyricsParser.parse("[01:00.00]one minute")
        XCTAssertEqual(result.first?.timeValue, 60.0, accuracy: 0.0001)
    }

    // MARK: - Multi-timestamp lines

    /// `[00:12.50][00:48.20]chorus line` is a single lyric shown at
    /// multiple timestamp positions. The parser must emit **two**
    /// `LyricLine` entries (one per timestamp) that share the same
    /// trailing text.
    func test_parse_multiTimestamp_emitsOneLinePerTimestamp() {
        let result = LyricsParser.parse("[00:12.50][00:48.20]chorus line")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].timeValue, 12.5, accuracy: 0.0001)
        XCTAssertEqual(result[1].timeValue, 48.2, accuracy: 0.0001)
        XCTAssertEqual(result[0].text, "chorus line")
        XCTAssertEqual(result[1].text, "chorus line")
    }

    func test_parse_multiTimestampInTextBody() {
        // Real-world pattern: one lyric-tag, then text, then another
        // tag, then more text. We treat only TAGs as timestamps.
        let result = LyricsParser.parse("[00:01.00]alpha[00:02.00]beta")
        XCTAssertGreaterThanOrEqual(result.count, 1)
        XCTAssertTrue(result.contains { abs($0.timeValue - 1.0) < 0.0001 })
        XCTAssertTrue(result.contains { abs($0.timeValue - 2.0) < 0.0001 })
    }

    // MARK: - Malformed input

    func test_parse_nonTimestampTagAtStart_returnsEmpty() {
        // `[ti:Title]` is metadata, not a lyric line — must be ignored.
        XCTAssertEqual(LyricsParser.parse("[ti:A]ignored"), [])
    }

    func test_parse_secondsAbove59_returnsNil() {
        // `[00:60.00]` is malformed (seconds must be < 60). The
        // entire line is dropped, not partially accepted.
        XCTAssertEqual(LyricsParser.parse("[00:60.00]bad"), [])
    }

    func test_parse_missingColon_returnsEmpty() {
        // `[00 12.50]` — no `:` → can't be a timestamp.
        XCTAssertEqual(LyricsParser.parse("[00 12.50]nope"), [])
    }

    func test_parse_unclosedBracket_returnsEmpty() {
        // `[00:12.50` (no closing `]`) → parser bails on the line.
        XCTAssertEqual(LyricsParser.parse("[00:12.50no close"), [])
    }

    // MARK: - Encoding tolerance

    func test_parse_stripsBOM() {
        let text = "\u{FEFF}[00:12.00]first"
        let result = LyricsParser.parse(text)
        XCTAssertEqual(result.first?.timeValue, 12.0, accuracy: 0.0001)
        XCTAssertEqual(result.first?.text, "first")
    }

    func test_parse_toleratesCRLF() {
        let text = "[00:01.00]first\r\n[00:02.00]second\r\n"
        let result = LyricsParser.parse(text)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].timeValue, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result[1].timeValue, 2.0, accuracy: 0.0001)
    }

    func testParse_toleratesMixedCRAndLF() {
        let text = "[00:01]a\r[00:02]b\n[00:03]c\n"
        let result = LyricsParser.parse(text)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.timeValue), [1.0, 2.0, 3.0])
    }

    // MARK: - LyricsNavigator (active-line search)

    func testNavigator_returnsNilForEmptyInputOrNegativeTime() {
        XCTAssertNil(LyricsNavigator.activeLine(in: [], at: 12))
        XCTAssertNil(LyricsNavigator.activeLine(in: [], at: -1))
        let one = [LyricLine(time: 12, text: "x")]
        XCTAssertNil(LyricsNavigator.activeLine(in: one, at: -0.5))
    }

    func testNavigator_returnsNilForTimeBeforeFirstLine() {
        let lines = [
            LyricLine(time: 12, text: "a"),
            LyricLine(time: 48, text: "b"),
        ]
        XCTAssertNil(LyricsNavigator.activeLine(in: lines, at: 0))
        XCTAssertNil(LyricsNavigator.activeLine(in: lines, at: 11.99))
    }

    func testNavigator_picksLastIndexWhoseTimeIsLessThanOrEqualToQuery() {
        let lines = [
            LyricLine(time: 12, text: "a"),
            LyricLine(time: 48, text: "b"),
        ]
        XCTAssertEqual(LyricsNavigator.activeLine(in: lines, at: 12.0), 0)
        XCTAssertEqual(LyricsNavigator.activeLine(in: lines, at: 47.9), 0)
        XCTAssertEqual(LyricsNavigator.activeLine(in: lines, at: 48.0), 1)
        XCTAssertEqual(LyricsNavigator.activeLine(in: lines, at: 60), 1)
    }

    func testNavigator_handlesDuplicateTimestamps() {
        // Two lines at the same time → returns the last one of the runs.
        let lines = [
            LyricLine(time: 10, text: "first 10"),
            LyricLine(time: 10, text: "second 10"),
        ]
        XCTAssertEqual(LyricsNavigator.activeLine(in: lines, at: 10.0), 1)
        XCTAssertEqual(LyricsNavigator.activeLine(in: lines, at: 9.99), 0)
    }
}
