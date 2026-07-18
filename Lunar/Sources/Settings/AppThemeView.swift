import SwiftUI
import Observation

/// Settings — App Theme with MeloPlayer styling.
@Observable
@MainActor
final class AppThemeSettings {
    static let modeKey = "Lunar.AppThemeMode"
    static let accentKey = "Lunar.AppAccentName"

    enum Mode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light:  .light
            case .dark:   .dark
            }
        }
    }

    enum Accent: String, CaseIterable, Identifiable {
        case purple, pink, cyan, orange, green, red, lime
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .purple: .purple
            case .pink:   ColorTokens.destructive.opacity(0.85)
            case .cyan:   Color(red: 0.27, green: 0.92, blue: 1.00)
            case .orange: ColorTokens.warning
            case .green:  Color(red: 0.20, green: 0.84, blue: 0.40)
            case .red:    ColorTokens.destructive
            case .lime:   ColorTokens.appAccent
            }
        }
    }

    var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }
    var accent: Accent {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: Self.accentKey) }
    }

    init() {
        self.mode = Mode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .system
        self.accent = Accent(rawValue: UserDefaults.standard.string(forKey: Self.accentKey) ?? "") ?? .lime
    }
}

struct AppThemeView: View {

    @Environment(AppThemeSettings.self) private var settings

    var body: some View {
        @Bindable var bindable = settings
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("App Theme")
                        .font(Typography.display)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                }

                settingsGroup(title: "Appearance") {
                    Picker("Theme", selection: $bindable.mode) {
                        ForEach(AppThemeSettings.Mode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .preferredColorScheme(settings.mode.colorScheme)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                }

                settingsGroup(title: "Accent Color") {
                    AccentGrid(selection: $bindable.accent)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
        .background(ColorTokens.canvas)
        .navigationTitle("App Theme")
        .toolbarColorScheme(.dark, for: .navigationBar)
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
}

// MARK: - AccentGrid

private struct AccentGrid: View {
    @Binding var selection: AppThemeSettings.Accent

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.m), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.m) {
            ForEach(AppThemeSettings.Accent.allCases) { accent in
                Button {
                    selection = accent
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 48, height: 48)
                            if selection == accent {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(selection == accent ? Color.white : ColorTokens.hairline, lineWidth: 2)
                        )
                        Text(accent.label)
                            .font(Typography.caption1)
                            .foregroundStyle(selection == accent ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.s)
    }
}
