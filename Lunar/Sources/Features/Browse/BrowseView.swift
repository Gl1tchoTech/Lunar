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
                    HStack {
                        Text("Browse")
                            .font(Typography.display)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Spacer()
                    }

                    LazyVGrid(columns: columns, spacing: Spacing.m) {
                        ForEach(categories) { category in
                            categoryCard(category)
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
        }
        .buttonStyle(.plain)
    }

    private var comingSoonFootnote: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "info.circle")
                .foregroundStyle(ColorTokens.appAccent)
            Text("Coming soon — Browse hosts the upcoming song downloader and streamer.")
                .font(Typography.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ColorTokens.surface)
        )
    }
}
