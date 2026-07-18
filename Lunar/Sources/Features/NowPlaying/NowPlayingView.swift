import SwiftUI

/// Full-screen Now Playing cover with MeloPlayer styling.
@MainActor
struct NowPlayingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager
    @Environment(SleepTimer.self) private var sleepTimer

    @State private var presentingSleepSheet = false
    @State private var presentingLyricsSheet = false

    var body: some View {
        let palette = themeManager.palette
        ZStack {
            palette.linearBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                dismissChrome(palette: palette)

                Spacer(minLength: Spacing.xl)

                artworkCard(palette: palette)

                Spacer(minLength: Spacing.xl)

                titleBlock(palette: palette)

                Spacer(minLength: Spacing.l)

                ScrubBar()
                    .padding(.horizontal, Spacing.l)

                Spacer(minLength: Spacing.l)

                TransportRow()
                    .padding(.horizontal, Spacing.l)

                Spacer(minLength: Spacing.xl)

                bottomActionBar(palette: palette)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xl)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $presentingSleepSheet) {
            SleepTimerSheet()
        }
        .sheet(isPresented: $presentingLyricsSheet) {
            LyricsView()
                .environment(engine)
                .environment(themeManager)
        }
    }

    // MARK: - Top chrome

    private func dismissChrome(palette: PlayerThemePalette) -> some View {
        HStack(spacing: Spacing.s) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: Spacing.iconBase, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Dismiss Now Playing")

            Spacer()

            SleepTimerChip(
                palette: palette,
                isActive: sleepTimer.isActive,
                secondsRemaining: sleepTimer.secondsRemaining,
                onTap: { presentingSleepSheet = true }
            )

            LyricsChip(
                palette: palette,
                onTap: { presentingLyricsSheet = true }
            )

            AirPlayRouteButton(palette: palette)

            if engine.currentQueueIndex >= 0 && engine.queueSize > 1 {
                Text("\(engine.currentQueueIndex + 1) / \(engine.queueSize)")
                    .font(Typography.caption1)
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.xl)
    }

    // MARK: - Artwork

    private func artworkCard(palette: PlayerThemePalette) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.railBackground)
                .shadow(color: .black.opacity(0.50), radius: 24, x: 0, y: 12)
            Image(systemName: "music.note")
                .font(.system(size: 96, weight: .thin))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(width: Spacing.albumArtLarge, height: Spacing.albumArtLarge)
        .accessibilityHidden(true)
    }

    // MARK: - Title block

    private func titleBlock(palette: PlayerThemePalette) -> some View {
        VStack(spacing: 6) {
            Text(engine.state.currentTitle)
                .font(Typography.title1)
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(engine.state.currentArtist)
                .font(Typography.title3)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.l)
    }

    // MARK: - Bottom action bar

    private func bottomActionBar(palette: PlayerThemePalette) -> some View {
        HStack(spacing: Spacing.xl) {
            Button { } label: {
                Image(systemName: "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .buttonStyle(.plain)

            Button { } label: {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .buttonStyle(.plain)

            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - SleepTimerChip

@MainActor
private struct SleepTimerChip: View {

    let palette: PlayerThemePalette
    let isActive: Bool
    let secondsRemaining: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: isActive ? "moon.fill" : "moon")
                    .font(.system(size: 14, weight: .semibold))
                if isActive {
                    Text(format(secondsRemaining))
                        .font(Typography.caption1)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(isActive ? palette.accent : palette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(palette.railBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Sleep timer — \(format(secondsRemaining)) remaining" : "Set sleep timer")
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - LyricsChip

@MainActor
private struct LyricsChip: View {

    let palette: PlayerThemePalette
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(palette.railBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lyrics")
    }
}
