import SwiftUI
import SwiftData

/// Library — Albums tab.
@MainActor
struct AlbumsView: View {

    @Query(sort: [SortDescriptor(\Album.title, order: .forward)])
    private var albums: [Album]

    var body: some View {
        Group {
            if albums.isEmpty {
                EmptyState(
                    title: "No albums yet",
                    message: "Once you import music, every album in your library will show up here.",
                    icon: {
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 60, weight: .light))
                    }
                )
            } else {
                albumsList
            }
        }
        .background(ColorTokens.canvas)
    }

    private var albumsList: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                HStack {
                    Text("\(albums.count) album\(albums.count == 1 ? "" : "s")")
                        .font(Typography.subhead)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)

                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        AlbumRow(album: album)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.l)
            }
            .padding(.top, Spacing.s)
            .padding(.bottom, 140)
        }
    }
}
