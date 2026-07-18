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
