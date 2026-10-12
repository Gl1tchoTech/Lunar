import SwiftUI

// MARK: — BrowseCategory

struct BrowseCategory: Identifiable, Hashable {
    let title: String
    let icon: String
    let gradient: [Color]

    var id: String { title }
}

private let categories: [BrowseCategory] = [
    BrowseCategory(title: "Top Charts",   icon: "chart.bar.fill",      gradient: [.pink,   .purple]),
    BrowseCategory(title: "Discover",     icon: "sparkles",            gradient: [.blue,   .cyan ]),
    BrowseCategory(title: "New Releases", icon: "sparkle",             gradient: [.orange, .pink ]),
    BrowseCategory(title: "Genres",       icon: "music.quarternote.3", gradient: [.green,  .mint ]),
    BrowseCategory(title: "Trending",     icon: "flame.fill",          gradient: [.red,    .orange]),
    BrowseCategory(title: "Featured",     icon: "star.fill",           gradient: [.indigo, .purple]),
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
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header

                    LazyVGrid(columns: columns, spacing: Spacing.m) {
                        ForEach(categories) { category in
                            categoryCard(category)
                                .accessibilityLabel(category.title)
                        }
                    }

                    comingSoonFootnote
                }
                .padding(Spacing.l)
                .padding(.bottom, 140)
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Browse")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Text("Browse")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
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
                    .fontWeight(.bold)
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(1)
    }

    private var comingSoonFootnote: some View {
        ComingSoonHeader(
            title: "Browse",
            message: "Browse will host the upcoming song discovery, charts, and streaming surfaces.",
            systemImage: "sparkles"
        )
    }
}
