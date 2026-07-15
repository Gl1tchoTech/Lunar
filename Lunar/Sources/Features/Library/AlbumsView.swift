import SwiftUI
import SwiftData

/// Library — Albums tab. Lists every Album entity in the library.
/// Tapping a row pushes `AlbumDetailView` for the album's song list.
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
        List {
            Section {
                sortChip
                    .listRowBackground(ColorTokens.canvas)
            }
            Section {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        AlbumRow(album: album)
                    }
                    .listRowBackground(ColorTokens.canvas)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var sortChip: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.up.arrow.down")
            Text("Album name (\(albums.count))")
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .font(Typography.subhead)
        .foregroundStyle(ColorTokens.textPrimary)
        .padding(.vertical, Spacing.s)
    }
}
