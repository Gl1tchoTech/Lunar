import Foundation
import AVFoundation

/// Cross-actor payload produced by `AudioMetadataExtractor`.
///
/// All fields are primitives or `Data` so the struct is `Sendable`.
/// The importer consumes this on the main actor and writes SwiftData.
struct ImportedTrackPayload: Sendable, Equatable {

    /// Absolute URL of the file AFTER it was copied into
    /// `MusicLibrary.rootDirectory`. Stored here so the main-actor
    /// pass can `removeItem` it again when the payload turns out to
    /// be a duplicate.
    let importedFileURL: URL

    /// Original basename from the document picker — used in the
    /// dedup fallback when metadata extraction returns nothing
    /// parseable.
    let originalFilename: String

    /// File size in bytes — used as a secondary dedup signal.
    let fileSize: Int64

    /// Codec family inferred from the file extension (`.mp3` → "MP3",
    /// `.m4a` → "AAC", `.wav` → "WAV", `.flac` → "FLAC"). `nil` when
    /// the extension is unknown.
    let format: String?

    /// Best-effort extraction of the common metadata tags.  Anything
    /// we couldn't read falls back to `nil` or a sensible placeholder
    /// (`title`/`artist` fall back to the file stem so the Library
    /// row isn't blank).
    let title: String
    let artist: String
    let albumTitle: String?
    let trackNumber: Int?
    let year: Int?
    let duration: TimeInterval

    /// Track-level audio properties (best-effort — many files won't
    /// expose them).
    let bitrate: Int?
    let sampleRate: Double?
    let bitDepth: Int?

    /// Embedded artwork bytes.  We keep up to ~2 MB; larger blobs are
    /// discarded because `Song.artwork` is `@Attribute(.externalStorage)`
    /// and we're already storing huge numbers of them.
    let artwork: Data?

    /// True when metadata extraction produced no usable title/artist
    /// (e.g. raw `.wav` with no tags). The importer falls back to
    /// `(originalFilename, fileSize)` for dedup in this case.
    var metadataIsFallback: Bool {
        title == originalFilename || artist == "Unknown Artist"
    }
}

// MARK: - AudioMetadataExtractor

/// Nonisolated AVAsset helper.
///
/// **Why nonisolated?** `AVAsset.load(...)` is async I/O and would
/// block the main actor for the duration of the file open + read on
/// big files. We isolate it on a detached task inside the static
/// functions, then hand back a Sendable payload.
///
/// **Why not an actor?** An actor would serialize concurrent import
/// batches unintentionally — `Task.detached` gives the same off-main
/// isolation without serializing across loads.
enum AudioMetadataExtractor {

    /// Maximum artwork blob we'll keep. Some files have 10 MB+ cover
    /// art that bloats the SwiftData store and slows list rendering.
    /// Songs with truly huge art still get `nil` and fall back to a
    /// generic placeholder card.
    static let maxArtworkBytes = 2 * 1024 * 1024

    /// Extract metadata from `url`. **Throws** on iCloud/permission
    /// failures or when the asset can't be opened at all (e.g. DRM,
    /// unsupported codec). The importer wraps this with a fallback so
    /// the Library never fails to import because one file was broken.
    static func extract(from url: URL) async throws -> ImportedTrackPayload {

        // Asset init is fine off-main. AVAsset loaded lazily so this
        // is just object allocation — no I/O happens yet.
        let asset = AVURLAsset(url: url)

        // Fire all loads in parallel — iOS 16+ favours this over
        // serialised reads.
        async let meta: [AVMetadataItem] = asset.load(.metadata)
        async let durRaw: CMTime    = asset.load(.duration)
        async let tracks: [AVAssetTrack] = asset.load(.tracks)
        async let common: [AVMetadataItem] = asset.load(.commonMetadata)

        let metadata   = (try? await meta)   ?? []
        let duration   = (try? await durRaw) ?? .zero
        let trackList  = (try? await tracks) ?? []
        let commonMeta = (try? await common) ?? []

        // MARK: strings
        let rawTitle  = stringValue(commonMeta, key: .commonKeyTitle)
            ?? stringValue(metadata,   key: .commonKeyTitle)
        let rawArtist = stringValue(commonMeta, key: .commonKeyArtist)
            ?? stringValue(metadata,   key: .commonKeyArtist)
        let rawAlbum  = stringValue(commonMeta, key: .commonKeyAlbumName)
            ?? stringValue(metadata,   key: .commonKeyAlbumName)

        let originalStem = url.deletingPathExtension().lastPathComponent
        let title  = rawTitle?.trimmedNonEmpty ?? originalStem
        let artist = rawArtist?.trimmedNonEmpty ?? "Unknown Artist"
        let albumTitle = rawAlbum?.trimmedNonEmpty

        // MARK: track number — uses .numberValue (NSNumber-aware)
        let trackNumber: Int? = {
            let item = findItem(commonMeta, key: .commonKeyTrackNumber)
                ?? findItem(metadata,   key: .commonKeyTrackNumber)
            guard let item else { return nil }
            if let asInt = item.numberValue?.intValue { return asInt }
            if let asStr = item.stringValue {
                // Some tags store "3/12" rather than a number — take
                // the run before the slash.
                let split = asStr.split(separator: "/").first.map(String.init)
                return split?.trimmedNonEmpty?.intValue
            }
            return nil
        }()

        // MARK: year — uses .dateValue / .stringValue
        let year: Int? = {
            let item = findItem(commonMeta, key: .commonKeyCreationDate)
                ?? findItem(metadata,   key: .commonKeyCreationDate)
            guard let item else { return nil }
            if let asDate = item.dateValue {
                return Calendar.current.component(.year, from: asDate)
            }
            if let asStr = item.stringValue {
                return asStr.prefix(4).intValue
            }
            return nil
        }()

        // MARK: duration
        let durationSeconds: TimeInterval = CMTimeGetSeconds(duration)

        // MARK: audio format (bitrate / sample rate / bit depth)
        let (bitrate, sampleRate, bitDepth) = firstAudioFormat(trackList: trackList)

        // MARK: artwork
        let artwork = firstArtworkData(commonMeta + metadata)

        // MARK: file helpers
        let fileSize = fileSizeOf(url)
        let formatFamily = inferFormat(extension: url.pathExtension)

        return ImportedTrackPayload(
            importedFileURL:   url,
            originalFilename:  url.lastPathComponent,
            fileSize:          fileSize,
            format:            formatFamily,
            title:             title,
            artist:            artist,
            albumTitle:        albumTitle,
            trackNumber:       trackNumber,
            year:              year,
            duration:          durationSeconds.isFinite ? durationSeconds : 0,
            bitrate:           bitrate,
            sampleRate:        sampleRate,
            bitDepth:          bitDepth,
            artwork:           artwork
        )
    }

    // MARK: - Helpers (private)

    private static func findItem(
        _ items: [AVMetadataItem],
        key: AVMetadataKey
    ) -> AVMetadataItem? {
        items.first { $0.commonKey == key }
    }

    /// Read the first string metadata tag. Uses `AVMetadataItem.stringValue`
    /// (iOS 16+) — the framework helper that transparently unpacks
    /// `NSString` / `NSNumber` wrappers for us.
    private static func stringValue(
        _ items: [AVMetadataItem],
        key: AVMetadataKey
    ) -> String? {
        findItem(items, key: key)?.stringValue?.trimmedNonEmpty
    }

    /// Pick the first artwork blob under the per-file cap. Uses
    /// `AVMetadataItem.dataValue` (iOS 16+) so the NSDictionary-wrapped
    /// MP4 artwork tags (where `item.value` is `{ "data": NSData, ... }`)
    /// are resolved automatically. Raw `NSData` tags work the same way.
    private static func firstArtworkData(_ items: [AVMetadataItem]) -> Data? {
        for item in items where item.commonKey == .commonKeyArtwork {
            guard let data = item.dataValue else { continue }
            if data.count <= maxArtworkBytes { return data }
        }
        return nil
    }

    /// Best-effort `(bitrate, sampleRate, bitDepth)` from the first
    /// audio track. Returns `(nil, nil, nil)` when no audio track exists.
    ///
    /// **Why `estimatedDataRate` instead of the format-description
    /// extension dict?** Both work, but `AVAssetTrack.estimatedDataRate`
    /// is the documented public-facing macro for compressed and
    /// uncompressed audio — formats like MP3 / AAC report VBR bitrates
    /// there without us poking at the C-core extensions dict.
    private static func firstAudioFormat(
        trackList: [AVAssetTrack]
    ) -> (bitrate: Int?, sampleRate: Double?, bitDepth: Int?) {
        guard let track = trackList.first(where: { $0.mediaType == .audio }) else {
            return (nil, nil, nil)
        }
        var bitrate: Int? = nil
        var sampleRate: Double? = nil
        var bitDepth: Int? = nil

        let estimatedBitsPerSecond = track.estimatedDataRate
        if estimatedBitsPerSecond > 0 {
            bitrate = Int(estimatedBitsPerSecond)
        }

        for desc in track.formatDescriptions {
            guard let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
            else { continue }
            if sampleRate == nil { sampleRate = basic.pointee.mSampleRate }
            if bitDepth   == nil { bitDepth   = Int(basic.pointee.mBitsPerChannel) }
        }
        return (bitrate, sampleRate, bitDepth)
    }

    private static func fileSizeOf(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func inferFormat(extension ext: String) -> String? {
        switch ext.lowercased() {
        case "mp3":           return "MP3"
        case "m4a", "aac",
             "mp4":           return "AAC"
        case "wav", "bwf":    return "WAV"
        case "flac":          return "FLAC"
        case "aiff", "aif":   return "AIFF"
        case "ogg", "oga":    return "OGG"
        case "opus":          return "Opus"
        default:              return nil
        }
    }
}

// MARK: - String convenience

private extension String {
    /// `nil` when the string is empty or only whitespace.
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// First run of digits in the receiver, parsed as `Int`.  Returns
    /// `nil` when there's no digit.
    var intValue: Int? {
        var digits = ""
        for char in self where char.isNumber { digits.append(char) }
        return digits.isEmpty ? nil : Int(digits)
    }
}
