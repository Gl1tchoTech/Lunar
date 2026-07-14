import SwiftUI

/// Settings ▸ Playback Setting.
///
/// Two controls driven by `PlaybackSettings`:
/// 1. **Crossfade Duration** — slider 0…12 s, snapped to 0.5 s. **0 s**
///    = direct cut (gapless if the toggle is also on).
/// 2. **Gapless Playback** — toggle. When ON the next song starts the
///    moment the current ends (with optional overlap from the slider).
///    When OFF a brief silence separates songs.
///
/// Both values persist to `UserDefaults` and propagate to the live
/// `AudioEngine` via `PlaybackSettings.onChange` (installed in
/// `LunarAppCoordinator`).
struct PlaybackSettingsView: View {

    @Environment(PlaybackSettings.self) private var settings

    var body: some View {
        @Bindable var bindable = settings
        Form {
            Section {
                CrossfadeSliderRow(
                    value: $bindable.crossfadeDurationSeconds
                )
            } header: {
                Text("Crossfade")
            } footer: {
                Text("How long two songs overlap when the queue advances. Set to 0 to skip the crossfade entirely.")
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Section {
                Toggle("Gapless Playback", isOn: $bindable.gaplessEnabled)
            } header: {
                Text("Continuity")
            } footer: {
                Text(gaplessFooterText)
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Section {
                playbackSummaryRow
            } header: {
                Text("Current")
            }
        }
        .scrollContentBackground(.hidden)
        .background(ColorTokens.canvas)
        .navigationTitle("Playback Setting")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Captions

    private var gaplessFooterText: String {
        if settings.gaplessEnabled {
            return "ON — the next song starts the moment the current ends. Combine with the crossfade slider above to choose the overlap duration."
        }
        return "OFF — a brief silence separates songs as the queue advances."
    }

    private var playbackSummaryRow: some View {
        HStack {
            Image(systemName: "speaker.wave.2")
                .foregroundStyle(ColorTokens.appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Currently")
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(summary)
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
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
}

// MARK: - CrossfadeSliderRow

/// A label + slider + live numeric readout, all bound to a single
/// `Double`. Reading the value through the binding keeps the
/// displayed `seconds` label in sync with the slider drag in real
/// time.
private struct CrossfadeSliderRow: View {

    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Duration")
                    .font(Typography.bodyBold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(label)
                    .font(Typography.bodyBold)
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

#Preview {
    PlaybackSettingsView()
        .environment(PlaybackSettings())
        .preferredColorScheme(.dark)
}
