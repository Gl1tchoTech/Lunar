import SwiftUI

// NOTE: This file is the single canonical PlaybackSettingsView for the
// Lunar module. A duplicate copy previously existed at
// `Lunar/Sources/Features/Settings/PlaybackSettingsView.swift`, which
// caused the Swift compile error:
//
//   "Filename 'PlaybackSettingsView.swift' used twice ... Filenames are
//    used to distinguish private declarations with the same name."
//
// That duplicate was removed. There should only ever be one
// `PlaybackSettingsView.swift` in this module.

/// Settings ▸ Playback Setting with MeloPlayer styling.
@MainActor
struct PlaybackSettingsView: View {

    @Environment(PlaybackSettings.self) private var settings

    var body: some View {
        @Bindable var bindable = settings
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("Playback")
                        .font(Typography.display)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                }

                settingsGroup {
                    CrossfadeSliderRow(
                        value: $bindable.crossfadeDurationSeconds
                    )
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                }

                settingsGroup {
                    Toggle("Gapless Playback", isOn: $bindable.gaplessEnabled)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .tint(ColorTokens.appAccent)
                }

                settingsGroup {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ColorTokens.appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently")
                                .font(Typography.caption1)
                                .foregroundStyle(ColorTokens.textSecondary)
                            Text(summary)
                                .font(Typography.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
        .background(ColorTokens.canvas)
        .navigationTitle("Playback Setting")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var summary: String {
        let fade = crossfadeLabel(settings.crossfadeDurationSeconds)
        if !settings.gaplessEnabled { return "Cut transition · \(fade)" }
        if settings.crossfadeDurationSeconds <= 0 { return "Pure gapless · \(fade)" }
        return "Gapless crossfade · \(fade)"
    }

    private func crossfadeLabel(_ seconds: Double) -> String {
        if seconds <= 0 { return "Off" }
        return String(format: "%.1f s", seconds)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .modifier(ColorTokens.glassCard(cornerRadius: 18))
    }
}

// MARK: - CrossfadeSliderRow

private struct CrossfadeSliderRow: View {

    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Crossfade Duration")
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(label)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.appAccent)
                    .monospacedDigit()
            }
            Slider(
                value: $value,
                in: PlaybackSettings.crossfadeRange,
                step: PlaybackSettings.crossfadeStep
            )
            .tint(ColorTokens.appAccent)
            .accessibilityLabel("Crossfade duration")
            .accessibilityValue(label)
        }
        .padding(.vertical, Spacing.xs)
    }

    private var label: String {
        if value <= 0 { return "Off" }
        return String(format: "%.1f s", value)
    }
}
