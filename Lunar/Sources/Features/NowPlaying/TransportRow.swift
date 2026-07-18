import SwiftUI

/// 5-button transport row with MeloPlayer styling.
@MainActor
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.railBackground.opacity(visibleRailOpacity))
        )
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
    }

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
    }

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
                .frame(width: 72, height: 72)
                .background(palette.accent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
