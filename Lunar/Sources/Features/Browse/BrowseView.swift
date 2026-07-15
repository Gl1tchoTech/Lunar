import SwiftUI

// MARK: — BrowseCategory

/// A single placeholder tile in the Browse grid. The full downloader /
/// streamer will hydrate these surfaces in a later release.
struct BrowseCategory: Identifiable, Hashable {
    let title: String
    let icon: String
    let gradient: [Color]

    var id: String { title }
}

private let categories: [BrowseCategory] = [
    BrowseCategory(title: "Top Charts",   icon: "chart.bar.fill",            gradient: [.pink,   .purple]),
    BrowseCategory(title: "Discover",     icon: "sparkles",                  gradient: [.blue,   .cyan ]),
    BrowseCategory(title: "New Releases", icon: "sparkle",                   gradient: [.orange, .pink ]),
    BrowseCategory(title: "Genres",       icon: "music.quarternote.3",       gradient: [.green,  .mint ]),
    BrowseCategory(title: "Trending",     icon: "flame.fill",                gradient: [.red,    .orange]),
    BrowseCategory(title: "Featured",     icon: "star.fill",                 gradient: [.indigo, .purple]),
]

// MARK: — BrowseView

@MainActor
struct BrowseView: View {

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.m),
        GridItem(.flexible(), spacing: Spacing.m),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.m) {
                    ForEach(categories) { category in
                        categoryCard(category)
                    }
                }
                .padding(Spacing.l)
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Browse")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                comingSoonFootnote
            }
        }
    }

    private func categoryCard(_ category: BrowseCategory) -> some View {
        Button {
            // Future: route to the matching category surface.
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(Spacing.s)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())

                Text(category.title)
                    .font(Typography.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .bottomLeading)
            .padding(Spacing.m)
            .background(
                LinearGradient(
                    colors: category.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var comingSoonFootnote: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "info.circle")
                .foregroundStyle(ColorTokens.textSecondary)
            Text("Coming soon — Browse hosts the upcoming song downloader and streamer.")
                .font(Typography.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    BrowseView()
        .preferredColorScheme(.dark)
}
