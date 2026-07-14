import SwiftUI

/// Settings — Player Style sheet. Vertical list of the six Player
/// Themes with a small preview card (gradient + accent color circle +
/// play button). Tap a card to set `PlayerThemeManager.current`.
struct PlayerStyleView: View {

    @Environment(PlayerThemeManager.self) private var manager

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                ForEach(PlayerThemeID.allCases) { id in
                    ThemePreviewCard(
                        themeID: id,
                        isSelected: manager.current == id,
                        onSelect: { manager.setTheme(id) }
                    )
                }
            }
            .padding(Spacing.l)
        }
        .background(ColorTokens.canvas)
        .navigationTitle("Player Style")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ThemePreviewCard

private struct ThemePreviewCard: View {
    let themeID: PlayerThemeID
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let palette = paletteFor(themeID)
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .bottom) {
                    Text(themeID.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.accent)
                            .font(.system(size: 22))
                    }
                }

                // Tripod preview: gradient + accent button + transport pills
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.linearBackground)
                    HStack {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .foregroundStyle(.black)
                                    .font(.system(size: 22, weight: .bold))
                            )
                        Spacer()
                        HStack(spacing: Spacing.xs) {
                            miniIcon(systemName: "backward.fill", palette: palette)
                            miniIcon(systemName: "forward.fill", palette: palette)
                        }
                    }
                    .padding(Spacing.m)
                }
                .frame(height: 92)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity)
            .background(palette.linearBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? palette.accent : ColorTokens.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func paletteFor(_ id: PlayerThemeID) -> PlayerThemePalette {
        switch id {
        case .cyberNeon:     return .cyberNeon
        case .vinylLime:     return .vinylLime
        case .aurora:        return .aurora
        case .vividOcean:    return .vividOcean
        case .sepiaWood:     return .sepiaWood
        case .pastelPlayful: return .pastelPlayful
        }
    }

    private func miniIcon(systemImage: String, palette: PlayerThemePalette) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(palette.primaryText)
            .frame(width: 32, height: 32)
            .background(palette.railBackground)
            .clipShape(Circle())
    }
}
