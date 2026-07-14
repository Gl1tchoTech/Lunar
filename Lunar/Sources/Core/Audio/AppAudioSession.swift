import Foundation
import AVFoundation
import Combine

/// Discrete session-related events the audio engine reacts to.
enum AudioEvent: Equatable, Sendable {
    /// Began (e.g. phone call). `shouldResume` from AVAudioSession if provided.
    case interruptionBegan(shouldResume: Bool)
    case interruptionEnded(shouldResume: Bool)
    /// Headphones unplugged / route otherwise changed away from output.
    case routeChanged(oldReason: AVAudioSession.RouteChangeReason)
}

/// Owns the app's `AVAudioSession`. Builds it once, activates it, and
/// bridges the system-level interruption / route-change notifications
/// into a typed `AudioEvent` stream the audio engine consumes.
///
/// Why a dedicated helper? `AVAudioSession.sharedInstance()` plus
/// `NotificationCenter.default` is a stringly-typed combination that's
/// easy to mis-wire. This class is the only place those strings live.
@MainActor
final class AppAudioSession {

    /// Subject the audio engine subscribes to. Any sink up the chain
    /// reads in chronological order.
    let events = PassthroughSubject<AudioEvent, Never>()

    private var subscriptions: Set<AnyCancellable> = []

    init() {
        configure()
        observeInterruption()
        observeRouteChange()
    }

    /// Activate `.playback` category so audio continues with screen
    /// off and under the lock screen.
    private func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback,
                                    mode: .moviePlayback,
                                    options: [.allowAirPlay])
            try session.setActive(true, options: [])
        } catch {
            // Loud-and-clear failure on launch is the right move —
            // a music app shipping without background audio is broken.
            assertionFailure("AVAudioSession configure failed: \(error)")
        }
    }

    private func observeInterruption() {
        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.handleInterruption(note)
            }
            .store(in: &subscriptions)
    }

    private func observeRouteChange() {
        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.handleRouteChange(note)
            }
            .store(in: &subscriptions)
    }

    private func handleInterruption(_ note: Notification) {
        let info = note.userInfo
        guard
            let rawType = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            events.send(.interruptionBegan(shouldResume: false))
        case .ended:
            let optsRaw = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
                .contains(.shouldResume)
            events.send(.interruptionEnded(shouldResume: shouldResume))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ note: Notification) {
        let info = note.userInfo
        guard
            let rawReason = info?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
        else { return }
        events.send(.routeChanged(oldReason: reason))
    }
}
