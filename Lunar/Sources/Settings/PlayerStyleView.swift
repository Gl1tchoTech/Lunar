import SwiftUI

/// Settings — Player Style with MeloPlayer styling.
@MainActor
struct PlayerStyleView: View {

    @Environment(PlayerThemeManager.self) private var manager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("Player Style")
                        .font(Typography.display)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                }

                VStack(spacing: Spacing.m) {
                    ForEach(PlayerThemeID.allCases) { id in
                        ThemePreviewCard(
                            themeID: id,
                            isSelected: manager.current == id,
                            onSelect: { manager.setTheme(id) }
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
        .background(ColorTokens.canvas)
        .navigationTitle("Player Style")
        .toolbarColorScheme(.dark, for: .navigationBar)
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
                            .foregroundStyle(ColorTokens.appAccent)
                            .font(.system(size: 22))
                    }
                }

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
                            miniIcon(systemImage: "backward.fill", palette: palette)
                            miniIcon(systemImage: "forward.fill", palette: palette)
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
                        isSelected ? ColorTokens.appAccent : ColorTokens.hairline,
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
