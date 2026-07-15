import SwiftUI

/// 5-button transport row: shuffle · prev · play-pause · next · repeat.
///
/// Drives `QueueSettings` (the **source of truth** — UserDefaults-backed)
/// for queue modes, and `AudioEngine` directly for prev/play/next.
/// Mirroring from `QueueSettings` → `AudioEngine.shuffleMode /
/// .repeatMode` happens in `LunarAppCoordinator.task` via the
/// `onChange` callback, so button taps here stay one-line.
///
/// **Queue mode glyphs** (always reflect the live `QueueSettings`):
/// - **shuffle** — `shuffle` (off) → `shuffle.circle.fill` (on, accent-tinted)
/// - **repeat** — `repeat` (off) → `repeat.circle.fill` (all) → `repeat.1.circle.fill` (one)
struct TransportRow: View {

    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager
    @Environment(QueueSettings.self) private var queueSettings

    var body: some View {
        let palette = themeManager.palette
        HStack(spacing: Spacing.xl) {
            shuffleButton(palette: palette)
            button(systemImage: "backward.fill", action: { engine.previous() }, palette: palette)
                .opacity(canGoPrev ? 1 : 0.4)
                .disabled(!canGoPrev)
            playPauseButton(palette: palette)
            button(systemImage: "forward.fill", action: { engine.next() }, palette: palette)
                .opacity(canGoNext ? 1 : 0.4)
                .disabled(!canGoNext)
            repeatButton(palette: palette)
        }
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity)
        .background(palette.railBackground.opacity(visibleRailOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
    }

    private var canGoPrev: Bool {
        engine.currentQueueIndex > 0 || engine.state.currentTime > 3
    }

    private var canGoNext: Bool {
        guard engine.queueSize > 0 else { return false }
        return engine.currentQueueIndex + 1 < engine.queueSize
    }

    private var visibleRailOpacity: Double {
        switch themeManager.current {
        case .sepiaWood, .pastelPlayful: return 0
        default: return 1
        }
    }

    // MARK: - Queue mode buttons

    /// Mutates `queueSettings.shuffleMode` directly. `didSet` writes
    /// to `UserDefaults` and fires `onChange`, which the coordinator
    /// pipes into `audioEngine.shuffleMode` — so the engine eventually
    /// follows even though we don't poke it here.
    private func shuffleButton(palette: PlayerThemePalette) -> some View {
        let isOn = queueSettings.shuffleMode == .on
        return Button {
            queueSettings.toggleShuffleMode()
        } label: {
            Image(systemName: queueSettings.shuffleMode.systemImage)
                .font(.system(size: Spacing.iconLarge, weight: .semibold))
                .foregroundStyle(isOn ? palette.accent : palette.primaryText)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Shuffle on" : "Shuffle off")
        .accessibilityHint("Toggles shuffling the upcoming queue")
    }

    /// Cycles `queueSettings.repeatMode` (off → all → one → off). The
    /// cycle is the local helper `nextRepeatMode(_:)` — a pure function
    /// for clarity + testability; `QueueSettings.cycleRepeatMode()` is
    /// the same cycle from a different call-site (any future
    /// programmatic toggles).
    private func repeatButton(palette: PlayerThemePalette) -> some View {
        let mode = queueSettings.repeatMode
        let isActive = mode != .off
        return Button {
            queueSettings.cycleRepeatMode()
        } label: {
            Image(systemName: mode.systemImage)
                .font(.system(size: Spacing.iconLarge, weight: .semibold))
                .foregroundStyle(isActive ? palette.accent : palette.primaryText)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(repeatAccessibilityLabel(mode))
        .accessibilityHint("Cycles repeat mode: Off → All → One")
    }

    private func nextRepeatMode(_ current: RepeatMode) -> RepeatMode {
        switch current {
        case .off:    .all
        case .all:    .one
        case .one:    .off
        }
    }

    private func repeatAccessibilityLabel(_ mode: RepeatMode) -> String {
        switch mode {
        case .off: "Repeat off"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }

    // MARK: - Generic buttons

    private func button(
        systemImage: String,
        action: (() -> Void)?,
        palette: PlayerThemePalette
    ) -> some View {
        Button(action: { action?() }) {
            Image(systemName: systemImage)
                .font(.system(size: Spacing.iconLarge, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func playPauseButton(palette: PlayerThemePalette) -> some View {
        Button {
            Task { await engine.send(.togglePlayPause) }
        } label: {
            Image(systemName: engine.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 64, height: 64)
                .background(palette.accent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.state.isPlaying ? "Pause" : "Play")
    }
}
