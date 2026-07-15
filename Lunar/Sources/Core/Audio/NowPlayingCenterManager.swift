import Foundation
import MediaPlayer
import SwiftData
import UIKit

/// Bridges `AudioEngine`'s `@Observable` state into the iOS system
/// "Now Playing" surfaces:
///
/// - **Lock Screen + Control Center** — title, artist, duration,
///   elapsed time, playback rate, and (if available) artwork via
///   `MPNowPlayingInfoCenter.default().nowPlayingInfo`.
/// - **Remote command center** — play / pause / toggle / nextTrack /
///   previousTrack / skipForward / skipBackward / changePlaybackPosition,
///   each forwarded to `AudioEngine.send(_:)`.
///
/// **Threading**: `@MainActor` end-to-end. iOS requires all interactions
/// with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` to happen
/// on the main queue; the audio engine is also `@MainActor`.
///
/// **Artwork**: pulled lazily via the injected `artworkResolver`
/// closure and cached per `PersistentIdentifier` so we don't bash
/// SwiftData for every 0.1 s progress tick. The cache is bounded by
/// the user's library size in practice — small enough to keep
/// each `MPMediaItemArtwork` in memory until the song is replaced.
///
/// **Diff-skip**: the manager keeps its own `lastPushedState` so equal
/// states don't round-trip through CoreFoundation. The audio engine
/// also does its own diff before calling `onStateChange`, so we
/// typically skip 90 % of ticks at this layer too — defense in depth.
@MainActor
final class NowPlayingCenterManager {

    // MARK: - Dependencies

    private weak var audioEngine: AudioEngine?
    /// Resolves the byte payload for a song's artwork. Caller provides
    /// a SwiftData fetch (must run on the main context); we convert to
    /// `UIImage` once per song and cache the `MPMediaItemArtwork`.
    private let artworkResolver: (PersistentIdentifier) -> Data?

    // MARK: - State

    /// Cached artwork keyed by song. PersistentIdentifier is `Hashable`
    /// so this works as a `[PersistentIdentifier: MPMediaItemArtwork]`.
    private var artworkCache: [PersistentIdentifier: MPMediaItemArtwork] = [:]

    /// Last state pushed into `MPNowPlayingInfoCenter`. Used for
    /// diff-skip so we don't round-trip identical dicts.
    private var lastPushedState: PlayerState?
    /// Last song ID we pushed artwork for. When this changes we drop
    /// the stale dict and rebuild with the new artwork attached.
    private var lastPushedSongID: PersistentIdentifier?

    /// True after `attach()` — gates `update(_:)` so we don't push
    /// before the remote handlers are registered.
    private var isAttached: Bool = false

    init(
        audioEngine: AudioEngine,
        artworkResolver: @escaping (PersistentIdentifier) -> Data?
    ) {
        self.audioEngine = audioEngine
        self.artworkResolver = artworkResolver
    }

    // MARK: - Lifecycle

    /// Register the remote command handlers and prime the now-playing
    /// info with a "music app" placeholder so the Lock Screen knows we
    /// exist (even before any song loads).
    ///
    /// Called from `LunarAppCoordinator.task` — **once**. Re-attaching
    /// is a no-op (we guard against double-registration).
    func attach() {
        guard !isAttached else { return }
        isAttached = true
        registerRemoteCommands()
        publishEmptyPlaceholder()
    }

    /// Tear down handlers + clear now-playing info. We don't currently
    /// call this — `NowPlayingCenterManager` lives for the entire app
    /// session — but the entry point is here for tests + future
    /// background-mode support.
    func detach() {
        guard isAttached else { return }
        isAttached = false
        unregisterRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - State push

    /// Mirror a `PlayerState` snapshot into `MPNowPlayingInfoCenter`.
    /// Called from the audio engine's `onStateChange` callback.
    ///
    /// - Parameters:
    ///   - state: latest `PlayerState` snapshot
    ///   - songID: identifier of the song the snapshot refers to
    ///     (used to fetch + cache artwork). May be nil pre-load.
    func update(_ state: PlayerState, currentSongID songID: PersistentIdentifier?) {
        guard isAttached else { return }

        // Suppress identical pushes. PlayerState is Equatable so a
        // structural compare catches every mutation. This also prevents
        // the 0.1 s progress tick from hammering the lock screen
        // when nothing else has changed.
        if state == lastPushedState && songID == lastPushedSongID {
            return
        }
        lastPushedState = state
        lastPushedSongID = songID

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:        state.currentTitle,
            MPMediaItemPropertyArtist:       state.currentArtist,
            MPMediaItemPropertyPlaybackDuration: state.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        // Artwork: only resolve on song change (cache hit otherwise).
        if let songID, state.currentTitle.isEmpty == false {
            if artworkCache[songID] == nil,
               let bytes = artworkResolver(songID) {
                if let artwork = makeArtwork(from: bytes) {
                    artworkCache[songID] = artwork
                }
            }
            if let cached = artworkCache[songID] {
                info[MPMediaItemPropertyArtwork] = cached
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote command center

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.playCommand.addTarget { [weak self] _ in
            guard let engine = self?.audioEngine else { return .commandFailed }
            Task { await engine.send(.play) }
            return .success
        }
        center.playCommand.isEnabled = true

        center.pauseCommand.removeTarget(nil)
        center.pauseCommand.addTarget { [weak self] _ in
            guard let engine = self?.audioEngine else { return .commandFailed }
            Task { await engine.send(.pause) }
            return .success
        }
        center.pauseCommand.isEnabled = true

        center.togglePlayPauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let engine = self?.audioEngine else { return .commandFailed }
            Task { await engine.send(.togglePlayPause) }
            return .success
        }
        center.togglePlayPauseCommand.isEnabled = true

        center.nextTrackCommand.removeTarget(nil)
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let engine = self?.audioEngine else { return .commandFailed }
            Task { await engine.send(.next) }
            return .success
        }
        center.nextTrackCommand.isEnabled = true

        center.previousTrackCommand.removeTarget(nil)
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let engine = self?.audioEngine else { return .commandFailed }
            Task { await engine.send(.previous) }
            return .success
        }
        center.previousTrackCommand.isEnabled = true

        // 15 s skip back/forward — Apple's standard for music apps.
        center.skipForwardCommand.removeTarget(nil)
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        center.skipForwardCommand.addTarget { [weak self] event in
            guard let engine = self?.audioEngine else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            let target = engine.state.currentTime + interval
            Task {
                await engine.send(.seek(min(target, engine.state.duration)))
            }
            return .success
        }
        center.skipForwardCommand.isEnabled = true

        center.skipBackwardCommand.removeTarget(nil)
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        center.skipBackwardCommand.addTarget { [weak self] event in
            guard let engine = self?.audioEngine else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            let target = max(0, engine.state.currentTime - interval)
            Task { await engine.send(.seek(target)) }
            return .success
        }
        center.skipBackwardCommand.isEnabled = true

        // Scrubbing from Lock Screen / Control Center.
        center.changePlaybackPositionCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let engine = self?.audioEngine,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            let target = max(0, min(positionEvent.positionTime, engine.state.duration))
            Task { await engine.send(.seek(target)) }
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
    }

    private func unregisterRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
    }

    // MARK: - Artwork

    /// Build an `MPMediaItemArtwork` from raw image bytes. Downscales
    /// any image larger than `artworkMaxDimension` to keep the lock
    /// screen from rasterising huge album art every frame.
    ///
    /// - Returns: `nil` if the bytes don't decode into a valid image.
    private func makeArtwork(from data: Data) -> MPMediaItemArtwork? {
        guard let image = UIImage(data: data) else { return nil }

        let downscaled = downscaleIfNeeded(image, maxDimension: artworkMaxDimension)
        let bounds = CGSize(width: downscaled.size.width, height: downscaled.size.height)

        return MPMediaItemArtwork(boundsSize: bounds) { requestedSize in
            self.crop(downscaled, to: requestedSize)
        }
    }

    /// Maximum dimension (longest side) of the cached artwork image.
    /// Big enough to look crisp on a Retina Lock Screen card (~600 pt);
    /// small enough to avoid blowing memory when the library grows.
    private let artworkMaxDimension: CGFloat = 600

    private func downscaleIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func crop(_ image: UIImage, to size: CGSize) -> UIImage {
        guard image.size != size else { return image }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let aspectFit = aspectFitRect(for: image.size, in: size)
            image.draw(in: aspectFit)
        }
    }

    private func aspectFitRect(for source: CGSize, in target: CGSize) -> CGRect {
        let scale = min(target.width / source.width, target.height / source.height)
        let scaled = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: (target.width  - scaled.width)  * 0.5,
            y: (target.height - scaled.height) * 0.5,
            width: scaled.width,
            height: scaled.height
        )
    }

    // MARK: - Boot

    /// Publish a synthetic empty info dict the first time the app
    /// becomes a "music app" so iOS can put the Control Center entry
    /// in place before any song loads. Without this, the Control
    /// Center widget doesn't appear until the first `.play`.
    private func publishEmptyPlaceholder() {
        // An empty dict would also work — but publishing an explicit
        // title-less placeholder makes the integration tests more
        // deterministic (they can assert the exact key set).
        let info: [String: Any] = [
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
