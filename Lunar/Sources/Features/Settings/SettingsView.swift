import SwiftUI

/// Settings tab — skeleton showing navigation rows. The destinations are
/// stubbed with `Text` placeholders that will be replaced with real views
/// (Player Style carousel, App Theme picker, Equalizer, …) in a later step.
struct SettingsView: View {

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Player Style",       systemImage: "tshirt",       to: playerStyleStub)
                    row("App Theme",          systemImage: "paintpalette", to: appThemeStub)
                    row("Equalizer",          systemImage: "slider.vertical.3", to: equalizerStub)
                    row("Playback Setting",   systemImage: "gear",         to: playbackStub)
                    row("Language",           systemImage: "globe",        to: languageStub)
                }

                Section {
                    row("Feedback",     systemImage: "envelope",    to: Text("Feedback form — coming soon"))
                    row("Rate Us",      systemImage: "hand.thumbsup", to: Text("Rate Us — coming soon"))
                    row("Privacy Policy", systemImage: "lock.shield", to: Text("Privacy Policy — coming soon"))
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.canvas)
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Row helper

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

    // MARK: - Stubbed destination views
    // Each one renders a tinted "coming soon" page so the row leads somewhere
    // visible. Replaced with the real surface in subsequent steps.

    private var playerStyleStub: some View {
        StubPage(
            title: "Player Style",
            message: "Six Player Themes — including Cyber Neon, Vinyl/Lime, Aurora, Vivid Ocean, Sepia Wood, and Pastel Playful — will live here.",
            systemImage: "tshirt"
        )
    }

    private var appThemeStub: some View {
        StubPage(
            title: "App Theme",
            message: "Dark / Light / System + accent color choice. Coming next.",
            systemImage: "paintpalette"
        )
    }

    private var equalizerStub: some View {
        StubPage(
            title: "Equalizer",
            message: "10-band DSP via AVAudioUnitEQ, with presets and reverb.",
            systemImage: "slider.vertical.3"
        )
    }

    private var playbackStub: some View {
        StubPage(
            title: "Playback Setting",
            message: "Crossfade, gapless playback, sleep timer.",
            systemImage: "gear"
        )
    }

    private var languageStub: some View {
        StubPage(
            title: "Language",
            message: "English (default). More locales coming soon.",
            systemImage: "globe"
        )
    }
}

// MARK: - StubPage

private struct StubPage: View {
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
        .preferredColorScheme(.dark)
}
