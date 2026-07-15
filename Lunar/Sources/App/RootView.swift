import SwiftUI
import SwiftData

/// Root container. Picks the appropriate navigation surface for the device:
/// iPhone → `TabView`, iPad → `NavigationSplitView` with a sidebar list.
///
/// Also runs **first-launch data seeding** on the main context via `.task`
/// (idempotent — no-op on subsequent launches).
struct RootView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass)   private var verticalSizeClass
    @Environment(\.modelContext)        private var modelContext

    @State private var selectedTab: AppTab = .library

    var body: some View {
        Group {
            if shouldUseSplitView {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detailContent
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                TabView(selection: $selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        destination(for: tab)
                            .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                            .tag(tab)
                    }
                }
            }
        }
        .task {
            // First-launch seeding. Idempotent — guarded by a fetchCount
            // check inside `Seed.seedBuiltInPresetsIfNeeded(_:)`.
            Seed.seedBuiltInPresetsIfNeeded(context: modelContext)
        }
    }

    // MARK: - Helpers

    /// Split view on large screens (iPad in any orientation).
    private var shouldUseSplitView: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    private var sidebar: some View {
        List {
            Section {
                ForEach(AppTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                }
            }
        }
        .navigationTitle("Lunar")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        destination(for: selectedTab)
            .id(selectedTab) // rebuild stack when selection changes
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .library:   LibraryView()
        case .playlist:  PlaylistView()
        case .importer:  ImportView()
        case .browse:    BrowseView()
        case .settings:  SettingsView()
        }
    }
}

#Preview("iPhone") {
    let container = try! ModelContainer(
        for: LunarSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return RootView()
        .environment(PlayerThemeManager())
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
