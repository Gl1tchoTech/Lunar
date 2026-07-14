import SwiftUI

/// 5-button transport row: shuffle · prev · play-pause · next · repeat.
/// Drives `AudioEngine` directly. Buttons disable themselves when
/// there's no queue room to move (first song / last song for prev / next).
struct TransportRow: View {

    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager

    var body: some View {
        let palette = themeManager.palette
        HStack(spacing: Spacing.xl) {
            button(systemImage: "shuffle", action: nil, palette: palette)
                .opacity(0.85)
            button(systemImage: "backward.fill", action: { engine.previous() }, palette: palette)
                .opacity(canGoPrev ? 1 : 0.4)
                .disabled(!canGoPrev)
            playPauseButton(palette: palette)
            button(systemImage: "forward.fill", action: { engine.next() }, palette: palette)
                .opacity(canGoNext ? 1 : 0.4)
                .disabled(!canGoNext)
            button(systemImage: "repeat", action: nil, palette: palette)
                .opacity(0.85)
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
        // No rail background on light themes (Sepia Wood / Pastel Playful).
        switch themeManager.current {
        case .sepiaWood, .pastelPlayful: return 0
        default: return 1
        }
    }

    // MARK: - Buttons

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
