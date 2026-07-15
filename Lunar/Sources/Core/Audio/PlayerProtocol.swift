import Foundation
import SwiftData

/// State snapshot published by the audio player. SwiftUI views bind
/// directly to these fields (via `@Observable` on the concrete impl).
struct PlayerState: Equatable {
    var currentTitle: String = ""
    var currentArtist: String = ""
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    /// 0.0 – 1.0 master volume.
    var volume: Float = 1.0
}

/// Identifies a song for the audio engine **without crossing the
/// SwiftData actor boundary**. Only the file URL and the display strings
/// are forwarded across actors; `PersistentIdentifier` stays on the
/// main context with the model.
struct PlaybackRequest: Sendable, Equatable {
    let songID: PersistentIdentifier
    let title: String
    let artist: String
    /// Pre-resolved absolute URL. The caller must construct this via
    /// `MusicLibrary.absoluteURL(forFileName:)` on the main thread.
    let fileURL: URL
    let duration: TimeInterval
}

/// Identifies the user's queue intent. The audio engine resolves the
/// rest internally.
enum PlaybackCommand: Sendable {
    case play
    case pause
    case togglePlayPause
    case next
    case previous
    case seek(TimeInterval)
    case load(PlaybackRequest)
    case crossfade(to: PlaybackRequest, durationSeconds: Double)
    case setVolume(Float)
    case setEQ(bands: [Float])
}

extension PlaybackCommand: Equatable {}

/// Public protocol that views + tests both consume.
///
/// Why a protocol (not just concrete `AudioEngine`)?
/// - SwiftUI Previews need a controllable fake
/// - Unit tests cannot run AVAudioEngine (requires audio hardware)
/// - Allows future swap to AVPlayer or engine-free implementation
///
/// Note: We deliberately do NOT require `Observable` here. The
/// concrete `@Observable final class AudioEngine` is what powers
/// SwiftUI bindings; the protocol only carries the API surface so
/// fakes are easy to author.
@MainActor
protocol AudioPlayerInterface: AnyObject {

    /// Latest player snapshot. Updated on the main actor every
    /// `progressTimerInterval` when playing.
    var state: PlayerState { get }

    /// Send a command. Async so callers may `await` completion of
    /// any cross-thread I/O before deciding their next move.
    func send(_ command: PlaybackCommand) async
}
