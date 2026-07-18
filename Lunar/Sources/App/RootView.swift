import SwiftUI
import SwiftData

/// Root container. Uses a custom ZStack layout with a floating glass
/// tab bar at the bottom and a floating mini-player above it.
@MainActor
struct RootView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var selectedTab: AppTab = .library
    @State private var presentingNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content area
            Group {
                switch selectedTab {
                case .library:  LibraryView()
                case .playlist: PlaylistView()
                case .importer: ImportView()
                case .browse:   BrowseView()
                case .settings: SettingsView()
                }
            }

            // Floating mini-player (above tab bar)
            VStack(spacing: 0) {
                Spacer()
                MiniPlayer(isPresented: $presentingNowPlaying)
                    .padding(.horizontal, Spacing.m)
                    .padding(.bottom, Spacing.s)
                FloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, Spacing.m)
                    .padding(.bottom, Spacing.s)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(ColorTokens.canvas.ignoresSafeArea())
        .task {
            Seed.seedBuiltInPresetsIfNeeded(context: modelContext)
        }
        .fullScreenCover(isPresented: $presentingNowPlaying) {
            NowPlayingView()
                .environment(audioEngine)
        }
    }
}

// MARK: - FloatingTabBar

/// MeloPlayer-style floating tab bar. Glassy dark pill with icon + label
/// rows, lime accent for the selected tab.
@MainActor
struct FloatingTabBar: View {

    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ColorTokens.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 4)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? ColorTokens.appAccent : ColorTokens.textSecondary)
                    .frame(height: 24)
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? ColorTokens.appAccent : ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

#Preview("iPhone") {
    let container = try! ModelContainer(
        for: LunarSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return RootView()
        .environment(AudioEngine())
        .environment(PlayerThemeManager())
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
