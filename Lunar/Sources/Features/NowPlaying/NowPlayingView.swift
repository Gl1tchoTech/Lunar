import SwiftUI

/// Full-screen Now Playing cover. Launched from a tap on the
/// `MiniPlayer` overlay. Hosts a Player-Theme gradient background,
/// large artwork, scrub bar, and 5-button transport row. Tap on the
/// dismiss arrow to slide down (calls `dismiss()`).
struct NowPlayingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioEngine.self) private var engine
    @Environment(PlayerThemeManager.self) private var themeManager

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
    }

    // MARK: - Top chrome

    private func dismissChrome(palette: PlayerThemePalette) -> some View {
        HStack {
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
            // track number / queue position pulled later (Step 5: queue sheet)
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
