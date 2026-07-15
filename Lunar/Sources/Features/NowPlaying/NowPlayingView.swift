import SwiftUI

/// Full-screen Now Playing cover. Launched from a tap on the
/// `MiniPlayer` overlay. Hosts a Player-Theme gradient background,
/// large artwork, scrub bar, and 5-button transport row. Tap on the
/// dismiss arrow to slide down (calls `dismiss()`).
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

            VStack(spacing: Spacing.xl) {
                dismissChrome(palette: palette)
                Spacer(minLength: Spacing.l)
                artworkCard(palette: palette)
                Spacer(minLength: Spacing.l)
                titleBlock(palette: palette)
                ScrubBar()
                TransportRow()
                Spacer(minLength: Spacing.l)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xl)
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
    }

    // MARK: - Artwork

    private func artworkCard(palette: PlayerThemePalette) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.railBackground)
                .shadow(color: .black.opacity(0.50), radius: 16, x: 0, y: 8)
            Image(systemName: "music.note")
                .font(.system(size: 96, weight: .thin))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(width: Spacing.albumArtLarge, height: Spacing.albumArtLarge)
        .accessibilityHidden(true)
    }

    // MARK: - Title block

    private func titleBlock(palette: PlayerThemePalette) -> some View {
        VStack(spacing: 4) {
            Text(engine.state.currentTitle)
                .font(Typography.title2)
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(engine.state.currentArtist)
                .font(Typography.subhead)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }
}

// MARK: - SleepTimerChip

/// Pill-shaped button in the Now Playing top chrome. Renders the moon
/// SF Symbol plus an optional countdown string. Tapping opens the
/// `SleepTimerSheet`. When the timer is off, only the icon shows.
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
        .accessibilityHint("Opens the sleep timer picker")
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - LyricsChip

/// Pill-shaped button in the Now Playing top chrome. Surfaces the
/// synced-lyrics sheet when tapped. Companion to `SleepTimerChip`.
/// Unlike the sleep chip we don't track per-tap state here — the
/// sheet itself reads back whether lines exist and shows an empty
/// state if the current song has no `.lrc` file.
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
        .accessibilityHint("Opens the synced lyrics viewer")
    }
}

#Preview {
    NowPlayingView()
        .environment(AudioEngine())
        .environment(PlayerThemeManager())
        .environment(SleepTimer())
        .preferredColorScheme(.dark)
}
