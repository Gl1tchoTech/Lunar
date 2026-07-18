import SwiftUI
import SwiftData

/// Settings ▸ Equalizer with MeloPlayer styling.
@MainActor
struct EqualizerView: View {

    @Environment(EQSettings.self) private var settings
    @Query(sort: [SortDescriptor(\EQPreset.name, order: .forward)])
    private var presets: [EQPreset]

    var body: some View {
        @Bindable var bindable = settings
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("Equalizer")
                        .font(Typography.display)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                }

                settingsGroup {
                    Toggle("Equalizer On", isOn: $bindable.isEnabled)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .tint(ColorTokens.appAccent)
                }

                settingsGroup {
                    BandsGrid(settings: settings)
                        .padding(.vertical, Spacing.s)
                }

                settingsGroup {
                    PresetChips(
                        presets: presets,
                        activeID: settings.currentPresetID,
                        onTap: { preset in
                            settings.apply(preset: preset)
                        }
                    )
                    .padding(.vertical, Spacing.s)
                }

                Button(role: .destructive) {
                    settings.reset()
                } label: {
                    HStack {
                        Spacer()
                        Label("Reset to Flat", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(ColorTokens.destructive)
                        Spacer()
                    }
                    .padding(.vertical, Spacing.m)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
        .background(ColorTokens.canvas)
        .navigationTitle("Equalizer")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ColorTokens.surface)
        )
    }
}

// MARK: - Bands Grid

private struct BandsGrid: View {

    @Bindable var settings: EQSettings

    private static let bandCenters: [Float] = [
        32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
    ]

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<BandsGrid.bandCenters.count, id: \.self) { index in
                BandColumn(
                    frequency: BandsGrid.bandCenters[index],
                    value: settings.bandBinding(at: index)
                )
            }
        }
        .padding(.horizontal, Spacing.s)
    }
}

private struct BandColumn: View {

    let frequency: Float
    @Binding var value: Float

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(formatFrequency(frequency))
                .font(Typography.caption2)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VerticalSlider(value: $value, in: -12...12, step: 0.5)
                .frame(height: 160)

            Text(String(format: "%+.1f", value))
                .font(Typography.caption1)
                .foregroundStyle(ColorTokens.textPrimary)
                .monospacedDigit()
        }
    }

    private func formatFrequency(_ value: Float) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

private struct VerticalSlider: View {

    @Binding var value: Float
    var bounds: ClosedRange<Float>
    var step: Float

    init(value: Binding<Float>, in range: ClosedRange<Float>, step: Float) {
        self._value = value
        self.bounds = range
        self.step = step
    }

    var body: some View {
        Slider(
            value: $value,
            in: bounds,
            step: step
        )
        .tint(ColorTokens.appAccent)
        .rotationEffect(.degrees(-90))
        .frame(width: 160, height: 32)
        .accessibilityLabel("Band gain")
        .accessibilityValue(String(format: "%+.1f dB", value))
    }
}

// MARK: - Preset Chips

private struct PresetChips: View {

    let presets: [EQPreset]
    let activeID: PersistentIdentifier?
    let onTap: (EQPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Presets")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, Spacing.m)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(presets) { preset in
                        let isActive = activeID == preset.id
                        Button {
                            onTap(preset)
                        } label: {
                            Text(preset.name)
                                .font(Typography.subhead)
                                .fontWeight(isActive ? .bold : .medium)
                                .foregroundStyle(isActive ? ColorTokens.canvas : ColorTokens.textPrimary)
                                .padding(.horizontal, Spacing.m)
                                .padding(.vertical, Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(isActive ? ColorTokens.appAccent : ColorTokens.elevated)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.m)
            }
        }
        .padding(.vertical, Spacing.s)
    }
}
