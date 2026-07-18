import SwiftUI

/// Full-screen Now Playing with MeloPlayer styling.
@MainActor
struct NowPlayingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager
    @Environment(SleepTimer.self) private var sleepTimer
    @Environment(\.modelContext) private var modelContext

    @State private var presentingSleepSheet = false
    @State private var presentingLyricsSheet = false
    @State private var presentingSpeedSheet = false
    @State private var presentingMoreMenu = false

    var body: some View {
        let palette = themeManager.palette
        ZStack {
            // Blurred artwork background
            artworkBackground(palette: palette)

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
        .sheet(isPresented: $presentingSpeedSheet) {
            PlaybackSpeedSheet()
                .environment(engine)
        }
    }

    // MARK: - Background

    private func artworkBackground(palette: PlayerThemePalette) -> some View {
        ZStack {
            palette.linearBackground
            Image(systemName: "music.note")
                .resizable()
                .scaledToFit()
                .frame(width: 600, height: 600)
                .foregroundStyle(palette.accent.opacity(0.08))
                .blur(radius: 80)
        }
        .ignoresSafeArea()
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
            favoriteButton(palette: palette)
            lyricsButton(palette: palette)

            Spacer()

            speedButton(palette: palette)
            moreButton(palette: palette)
        }
        .padding(.horizontal, Spacing.xl)
    }

    private func favoriteButton(palette: PlayerThemePalette) -> some View {
        Button {
            guard let id = engine.currentSongID,
                  let song = modelContext.model(for: id) as? Song
            else { return }
            let service = LibraryService(context: modelContext)
            service.toggleFavorite(song)
        } label: {
            Image(systemName: currentSongIsFavorite ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(currentSongIsFavorite ? ColorTokens.appAccent : palette.primaryText)
        }
        .buttonStyle(.plain)
    }

    private var currentSongIsFavorite: Bool {
        guard let id = engine.currentSongID,
              let song = modelContext.model(for: id) as? Song
        else { return false }
        return song.isFavorite
    }

    private func lyricsButton(palette: PlayerThemePalette) -> some View {
        Button {
            presentingLyricsSheet = true
        } label: {
            Image(systemName: "text.alignleft")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.primaryText)
        }
        .buttonStyle(.plain)
    }

    private func speedButton(palette: PlayerThemePalette) -> some View {
        Button {
            presentingSpeedSheet = true
        } label: {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.primaryText)
        }
        .buttonStyle(.plain)
    }

    private func moreButton(palette: PlayerThemePalette) -> some View {
        Menu {
            Button {
                // Route picker is handled by AirPlay button; this is a fallback.
            } label: {
                Label("AirPlay & Speakers", systemImage: "airplayaudio")
            }
            Button {
                // Share current song
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.primaryText)
        }
        .buttonStyle(.plain)
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
