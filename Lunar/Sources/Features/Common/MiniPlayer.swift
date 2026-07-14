import SwiftUI

/// Persistent mini-player dock. Sits just above the tab bar whenever
/// a song is loaded, hidden otherwise. Tap launches the full
/// `NowPlayingView` cover via the bound `Bool`.
///
/// Docked via `.safeAreaInset(edge: .bottom)` on each tab's root
/// container (Library, Playlist, Import).
struct MiniPlayer: View {

    @Binding var isPresented: Bool

    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager

    var body: some View {
        if engine.state.currentTitle.isEmpty {
            EmptyView()
        } else {
            let palette = themeManager.palette
            Button {
                isPresented = true
            } label: {
                HStack(spacing: Spacing.s) {
                    artworkThumb(palette: palette)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.state.currentTitle)
                            .font(Typography.subhead)
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)
                        Text(engine.state.currentArtist)
                            .font(Typography.caption1)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Spacing.xs)

                    Button {
                        Task { await engine.send(.togglePlayPause) }
                    } label: {
                        Image(systemName: engine.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: Spacing.iconBase, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(palette.accent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(engine.state.isPlaying ? "Pause" : "Play")

                    Button {
                        engine.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: Spacing.iconBase, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next track")
                }
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, 6)
                .background(palette.railBackground)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
                .padding(.horizontal, Spacing.s)
                .padding(.bottom, Spacing.xs)
                .shadow(color: .black.opacity(0.40), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func artworkThumb(palette: PlayerThemePalette) -> some View {
        ZStack {
            palette.accent.opacity(0.20)
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(palette.primaryText)
        }
    }
}
