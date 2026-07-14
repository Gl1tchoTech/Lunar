import SwiftUI

/// Sleep Timer sheet. Shows the locked choices (Off / 5 / 15 / 30 / 45
/// / 60 minutes) as a grid of pills. Selecting a value updates
/// `SleepTimer` instantly and dismisses the sheet.
///
/// Used by:
/// - the **moon chip** in the Now Playing top chrome (primary entry)
/// - the **Settings → Sleep Timer** row
///
/// Reusable across both surfaces so the visual + interaction stays
/// in lock-step. Styling reads the active Player Theme via the shared
/// `PlayerThemeManager` so the chip color tracks whatever theme the
/// user picked.
struct SleepTimerSheet: View {

    @Environment(SleepTimer.self) private var timer
    @Environment(PlayerThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    private static let choices: [Int] = [0] + SleepTimer.supportedMinutes

    var body: some View {
        let palette = themeManager.palette

        NavigationStack {
            ZStack {
                palette.linearBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Spacing.l) {
                    statusPanel(palette: palette)
                    pillsGrid(palette: palette)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Typography.subhead)
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Status panel

    @ViewBuilder
    private func statusPanel(palette: PlayerThemePalette) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: timer.isActive ? "moon.fill" : "moon")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(timer.isActive ? palette.accent : palette.primaryText)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(palette.railBackground)
                )

            VStack(alignment: .leading, spacing: 4) {
                if timer.isActive {
                    Text("Sleeps in")
                        .font(Typography.subhead)
                        .foregroundStyle(palette.secondaryText)
                    Text(formatRemaining(timer.secondsRemaining))
                        .font(Typography.title2)
                        .foregroundStyle(palette.primaryText)
                        .monospacedDigit()
                } else {
                    Text("Off")
                        .font(Typography.title2)
                        .foregroundStyle(palette.primaryText)
                    Text("Choose a duration to pause Lunar automatically.")
                        .font(Typography.subhead)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Pills

    private func pillsGrid(palette: PlayerThemePalette) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Spacing.m),
            count: 3
        )
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("DURATION")
                .font(Typography.caption1)
                .foregroundStyle(palette.secondaryText)

            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(Self.choices, id: \.self) { minutes in
                    DurationPill(
                        minutes: minutes,
                        isSelected: timer.durationMinutes == minutes,
                        onSelect: {
                            timer.select(minutes: minutes)
                            // Dismiss after a short delay so the user sees
                            // the selection "land" in the status panel.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                dismiss()
                            }
                        },
                        palette: palette
                    )
                }
            }
        }
    }

    // MARK: - Format helpers

    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - DurationPill

/// Single tap target in the Sleep Timer grid. Shows the duration label
/// ("Off" / "5 min" / …) and an active check when the timer matches.
private struct DurationPill: View {

    let minutes: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let palette: PlayerThemePalette

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(labelTitle)
                    .font(Typography.bodyBold)
                    .foregroundStyle(
                        isSelected ? .black : palette.primaryText
                    )
                Text(labelSubtitle)
                    .font(Typography.caption1)
                    .foregroundStyle(
                        isSelected
                            ? .black.opacity(0.80)
                            : palette.secondaryText
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(
                RoundedRectangle(
                    cornerRadius: Spacing.cardCornerRadius,
                    style: .continuous
                )
                .fill(isSelected ? palette.accent : palette.railBackground)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: Spacing.cardCornerRadius,
                    style: .continuous
                )
                .stroke(
                    isSelected ? Color.clear : palette.railBackground,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(labelTitle), \(labelSubtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var labelTitle: String {
        minutes == 0 ? "Off" : "\(minutes)"
    }

    private var labelSubtitle: String {
        minutes == 0 ? "no timer" : "min"
    }
}

#Preview {
    SleepTimerSheet()
        .environment(SleepTimer())
        .environment(PlayerThemeManager())
        .preferredColorScheme(.dark)
}
