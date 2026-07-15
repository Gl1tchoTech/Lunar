import SwiftUI

/// Settings tab. Row-driven nav.
///
/// **Tier 4** (current pass):
///   • Equalizer, Playback Setting, About — all real destinations.
///   • Language stub row was removed — iOS follows the device locale
///     automatically and Lunar ships en-only for now; no per-app
///     override is exposed.
///
/// **Still stubbed (deliberately — user-deferred work):** Feedback,
/// Rate Us, Privacy Policy. Each opens a `StubPage` placeholder.
///
/// **Sleep Timer** uses a Button + sheet pattern so the same
/// `SleepTimerSheet` powers both this row and the moon chip in
/// Now Playing.
struct SettingsView: View {

    @Environment(SleepTimer.self) private var sleepTimer

    @State private var presentingSleepSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Player Style",       systemImage: "tshirt",       to: PlayerStyleView())
                    row("App Theme",          systemImage: "paintpalette", to: AppThemeView())
                    sleepTimerRow
                    row("Equalizer",          systemImage: "slider.vertical.3", to: EqualizerView())
                    row("Playback Setting",   systemImage: "gear",         to: PlaybackSettingsView())
                }

                Section {
                    row("About", systemImage: "info.circle", to: AboutView())
                }

                Section {
                    row("Feedback",     systemImage: "envelope",    to: StubPage(
                        title: "Feedback",
                        message: "Reach the dev team directly. Coming soon.",
                        systemImage: "envelope"
                    ))
                    row("Rate Us",      systemImage: "hand.thumbsup", to: StubPage(
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.canvas)
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $presentingSleepSheet) {
            SleepTimerSheet()
        }
    }

    // MARK: - Row helpers

    private func row<Destination: View>(
        _ title: String,
        systemImage: String,
        to destination: Destination
    ) -> some View {
        NavigationLink {
            destination
                .background(ColorTokens.canvas)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    /// Sleep Timer uses a Button + sheet (not a NavigationLink) so the
    /// same `SleepTimerSheet` powers both this row and the moon chip
    /// in Now Playing. Trailing value shows the current duration.
    private var sleepTimerRow: some View {
        Button {
            presentingSleepSheet = true
        } label: {
            HStack {
                Label("Sleep Timer", systemImage: "moon")
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(sleepTimerTrailingLabel)
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sleepTimerTrailingLabel: String {
        if sleepTimer.durationMinutes == 0 { return "Off" }
        return "\(sleepTimer.durationMinutes) min"
    }

    // MARK: - Stubbed destination views
    //
    // Player Style, App Theme, Playback Setting, Equalizer, About —
    // all real destinations, each living in its own file under
    // `Sources/Features/Settings/` (or `Sources/Settings/`).
    //
    // Feedback, Rate Us, Privacy Policy remain `StubPage` placeholders
    // by explicit user deferral.
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

#Preview {
    SettingsView()
        .environment(AppThemeSettings())
        .environment(SleepTimer())
        .environment(PlaybackSettings())
        .preferredColorScheme(.dark)
}
