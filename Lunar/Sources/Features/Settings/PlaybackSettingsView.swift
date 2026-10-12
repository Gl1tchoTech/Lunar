import SwiftUI

/// Settings ▸ Playback Setting with MeloPlayer styling.
@MainActor
struct PlaybackSettingsView: View {

    @Environment(PlaybackSettings.self) private var settings

    var body: some View {
        @Bindable var bindable = settings
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                settingsGroup {
                    Toggle(\"Crossfade\", isOn: $bindable.crossfadeEnabled)
                        .tint(ColorTokens.appAccent)
                }

                if bindable.crossfadeEnabled {
                    settingsGroup {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            HStack {
                                Text(\"Duration\")
                                    .font(Typography.body)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Spacer()
                                Text(formatSeconds(bindable.crossfadeDurationSeconds))
                                    .font(Typography.subhead)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: $bindable.crossfadeDurationSeconds,
                                in: 1...12,
                                step: 1
                            )
                            .tint(ColorTokens.appAccent)
                        }
                        .padding(.horizontal, Spacing.m)
                    }
                }

                settingsGroup {
                    Toggle(\"Gapless Playback\", isOn: $bindable.gaplessEnabled)
                        .tint(ColorTokens.appAccent)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
        .background(ColorTokens.canvas)
        .navigationTitle(\"Playback Setting\")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Text(\"Playback Setting\")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .modifier(ColorTokens.glassCard(cornerRadius: 18))
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s == 1 ? \"1 sec\" : \"\\(s) secs\"
    }
}
