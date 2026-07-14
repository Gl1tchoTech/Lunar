import SwiftUI

/// Settings tab. Row-driven nav. Most destinations are still stubs
/// (Equalizer/Playback/Language/About) — replaced in Phase 5.
struct SettingsView: View {

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Player Style",       systemImage: "tshirt",       to: PlayerStyleView())
                    row("App Theme",          systemImage: "paintpalette", to: AppThemeView())
                    row("Equalizer",          systemImage: "slider.vertical.3", to: equalizerStub)
                    row("Playback Setting",   systemImage: "gear",         to: playbackStub)
                    row("Language",           systemImage: "globe",        to: languageStub)
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

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.4.0")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    HStack {
                        Text("Made with")
                        Spacer()
                        Text("\u{1F319} SwiftUI + AVAudioEngine")
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
    // Real sub-views (Player Style + App Theme) live in `Sources/Settings/`.
    // The remainder are placeholders Step 5 will replace.

    private var equalizerStub: some View {
        StubPage(
            title: "Equalizer",
            message: "10-band DSP via AVAudioUnitEQ, with presets and reverb. Step 5.",
            systemImage: "slider.vertical.3"
        )
    }

    private var playbackStub: some View {
        StubPage(
            title: "Playback Setting",
            message: "Crossfade duration, gapless playback, and sleep timer controls. Step 5.",
            systemImage: "gear"
        )
    }

    private var languageStub: some View {
        StubPage(
            title: "Language",
            message: "English (default) for now. More locales coming in a follow-up.",
            systemImage: "globe"
        )
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

#Preview {
    SettingsView()
        .environment(AppThemeSettings())
        .preferredColorScheme(.dark)
}
