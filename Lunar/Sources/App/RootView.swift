import SwiftUI

/// Root container. Picks the appropriate navigation surface for the device:
/// iPhone → `TabView`, iPad → `NavigationSplitView` with a sidebar list.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass)   private var verticalSizeClass
    @State private var selectedTab: AppTab = .library

    var body: some View {
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

    // MARK: - Helpers

    /// Split view on large screens (iPad in any orientation).
    private var shouldUseSplitView: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    private var sidebar: some View {
        List(selection: $selectedTab) {
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
    RootView()
        .environment(PlayerThemeManager())
        .preferredColorScheme(.dark)
}
