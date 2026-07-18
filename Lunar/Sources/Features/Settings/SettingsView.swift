import SwiftUI

/// Settings tab with MeloPlayer-style grouped rounded cards.
@MainActor
struct SettingsView: View {

    @Environment(SleepTimer.self) private var sleepTimer

    @State private var presentingSleepSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header

                    settingsGroup(title: "Appearance") {
                        row("Player Style", systemImage: "tshirt", to: PlayerStyleView())
                        row("App Theme", systemImage: "paintpalette", to: AppThemeView())
                    }

                    settingsGroup(title: "Playback") {
                        sleepTimerRow
                        row("Equalizer", systemImage: "slider.vertical.3", to: EqualizerView())
                        row("Playback Setting", systemImage: "gear", to: PlaybackSettingsView())
                    }

                    settingsGroup(title: "About") {
                        row("About", systemImage: "info.circle", to: AboutView())
                    }

                    settingsGroup(title: "More") {
                        row("Feedback", systemImage: "envelope", to: StubPage(
                            title: "Feedback",
                            message: "Reach the dev team directly. Coming soon.",
                            systemImage: "envelope"
                        ))
                        row("Rate Us", systemImage: "hand.thumbsup", to: StubPage(
                            title: "Rate Us",
                            message: "If Lunar makes your day a little better, we'd love a review.",
                            systemImage: "hand.thumbsup"
                        ))
                        row("Privacy Policy", systemImage: "lock.shield", to: StubPage(
                            title: "Privacy Policy",
                            message: "Lunar is local-first. This page will lay out the full policy.",
                            systemImage: "lock.shield"
                        ))
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, 140)
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $presentingSleepSheet) {
            SleepTimerSheet()
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, Spacing.xs)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ColorTokens.surface)
            )
        }
    }

    private func row<Destination: View>(
        _ title: String,
        systemImage: String,
        to destination: Destination
    ) -> some View {
        NavigationLink {
            destination
                .background(ColorTokens.canvas)
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.appAccent)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
        }
    }

    private var sleepTimerRow: some View {
        Button {
            presentingSleepSheet = true
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "moon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.appAccent)
                    .frame(width: 28, height: 28)
                Text("Sleep Timer")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(sleepTimerTrailingLabel)
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sleepTimerTrailingLabel: String {
        if sleepTimer.durationMinutes == 0 { return "Off" }
        return "\(sleepTimer.durationMinutes) min"
    }
}

// MARK: - StubPage

struct StubPage: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        EmptyState(
            title: title,
            message: message,
            icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 60, weight: .light))
            }
        )
    }
}
