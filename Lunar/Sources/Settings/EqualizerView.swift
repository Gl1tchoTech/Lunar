import SwiftUI
import SwiftData

/// Settings ▸ Equalizer.
///
/// Four sections:
/// 1. **Master Enable**: a single toggle that turns the DSP on/off.
/// 2. **Bands**: 10 vertical sliders, one per ISO band center. Built
///    via the standard `Slider` rotated -90° — gives us free
///    VoiceOver, keyboard focus, and haptic feedback.
/// 3. **Presets**: horizontal chip row over the @Query'd EQPreset
///    table.
/// 4. **Reset**: zeros the bands. The on/off toggle stays where the
///    user set it.
struct EqualizerView: View {

    @Environment(EQSettings.self) private var settings
    // Sort by name only — `Bool` isn't Comparable in SwiftData so we
    // can't sort by `isBuiltIn`. The 13 factory presets all ship
    // with `dateCreated = epoch` so a date sort would put them at
    // the bottom. Name sort keeps a stable alphabetical order with
    // "Flat" as the natural anchor.
    @Query(sort: [SortDescriptor(\EQPreset.name, order: .forward)])
    private var presets: [EQPreset]

    var body: some View {
        @Bindable var bindable = settings
        Form {
            Section {
                Toggle("Equalizer On", isOn: $bindable.isEnabled)
            } header: {
                Text("Master")
            } footer: {
                Text(isEnabledFooter)
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Section {
                BandsGrid(settings: settings)
            } header: {
                HStack {
                    Text("Bands")
                    Spacer()
                    if settings.currentPresetID == nil && !isAllFlat {
                        Text("Custom")
                            .font(Typography.caption1)
                            .foregroundStyle(ColorTokens.appAccent)
                    }
                }
            } footer: {
                Text("Each vertical slider adjusts one band. Range ±12 dB in 0.5 dB steps. The centre line is 0 dB.")
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Section {
                PresetChips(
                    presets: presets,
                    activeID: settings.currentPresetID,
                    onTap: { preset in
                        settings.apply(preset: preset)
                    }
                )
            } header: {
                Text("Presets")
            }

            Section {
                Button(role: .destructive) {
                    settings.reset()
                } label: {
                    Label("Reset to Flat", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(ColorTokens.destructive)
                }
            } footer: {
                Text("Zeros all bands and clears the active preset. The on/off toggle above stays where you set it.")
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ColorTokens.canvas)
        .navigationTitle("Equalizer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Belt-and-suspenders @MainActor annotation: `EQSettings` is
    // annotated `@MainActor @Observable` (with stored properties now
    // explicitly `nonisolated`, see `EQSettings.swift`'s doc comments
    // for the rationale). Marking these computed properties with
    // explicit `@MainActor` ensures the reads compile cleanly even
    // under stricter Swift 6 concurrency settings that the project
    // may opt into later. Costs nothing at runtime and keeps the
    // semantic intent (`isEnabledFooter`/`isAllFlat` are UI-time
    // computations) declarative.
    @MainActor
    private var isEnabledFooter: String {
        settings.isEnabled
            ? "ON — your custom DSP is applied in-line with the audio. Tap below to disable for a clean bypass."
            : "OFF — audio passes through untouched. The band values below are preserved for when you re-enable."
    }

    @MainActor
    private var isAllFlat: Bool {
        settings.bands.allSatisfy { abs($0) < 0.05 }
    }
}

// MARK: - BandsGrid

/// Half-screen-tall row of 10 vertical sliders. Receives
/// `EQSettings` so each column can grab a per-band binding via
/// `settings.bandBinding(at:)` (iOS 17 SwiftUI doesn't expand
/// `$store.bands[i]` into a working two-way binding).
private struct BandsGrid: View {

    let settings: EQSettings

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(EQController.isoBandCentersHz.enumerated()), id: \.offset) { idx, hz in
                BandColumn(
                    hz: hz,
                    value: settings.bandBinding(at: idx)
                )
            }
        }
        .frame(height: 200)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - BandColumn

/// One vertical slider with its Hz label above and dB readout below.
private struct BandColumn: View {

    let hz: Double
    @Binding var value: Float

    var body: some View {
        VStack(spacing: 4) {
            Text(label(forHz: hz))
                .font(Typography.caption2)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VerticalSlider(value: $value)
                .frame(maxHeight: .infinity)
            Text(formattedGain)
                .font(Typography.caption1)
                .foregroundStyle(ColorTokens.appAccent)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var formattedGain: String {
        let clamped = max(-12.0, min(12.0, Double(value)))
        if abs(clamped) < 0.05 { return "0" }
        return String(format: clamped > 0 ? "+%.1f" : "%.1f", clamped)
    }

    private func label(forHz hz: Double) -> String {
        if hz >= 1_000 {
            let k = hz / 1_000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.0fk", k)
        }
        return "\(Int(hz))"
    }
}

// MARK: - VerticalSlider (rotated native Slider)

/// The native `Slider` rotated -90° so it sits vertically. Post-
/// rotation, the slider's visible *width* becomes its height and
/// vice versa; we set `.frame(width: visibleHeight,
/// height: visibleWidth)` to swap.
private struct VerticalSlider: View {

    @Binding var value: Float

    var body: some View {
        Slider(
            value: $value,
            in: EQSettings.bandRange,
            step: EQSettings.bandStep
        )
        .tint(ColorTokens.appAccent)
        .rotationEffect(.degrees(-90))
        .frame(width: 160, height: 28)
        .accessibilityLabel("Band gain")
        .accessibilityValue("\(Int(round(value * 10))) tenths of a decibel")
    }
}

// MARK: - PresetChips

/// Horizontal scrolling row of tappable chips, one per @Query'd preset.
private struct PresetChips: View {

    let presets: [EQPreset]
    let activeID: PersistentIdentifier?
    let onTap: (EQPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(presets) { preset in
                    let isActive = preset.persistentModelID == activeID
                    Button {
                        onTap(preset)
                    } label: {
                        VStack(spacing: 2) {
                            Text(preset.name)
                                .font(Typography.subhead)
                                .foregroundStyle(isActive ? .black : ColorTokens.textPrimary)
                            Text(preset.isBuiltIn ? "Built-in" : "Custom")
                                .font(Typography.caption2)
                                .foregroundStyle(isActive ? .black.opacity(0.7) : ColorTokens.textTertiary)
                        }
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule().fill(isActive ? ColorTokens.appAccent : ColorTokens.surface)
                        )
                        .overlay(
                            Capsule().stroke(
                                isActive ? ColorTokens.appAccent : ColorTokens.hairline,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: LunarSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    Seed.seedBuiltInPresetsIfNeeded(context: context)
    return NavigationStack {
        EqualizerView()
            .environment(EQSettings())
            .modelContainer(container)
            .preferredColorScheme(.dark)
    }
}
