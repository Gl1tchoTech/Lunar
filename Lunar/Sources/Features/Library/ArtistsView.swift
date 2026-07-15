import SwiftUI
import SwiftData

/// Library — Artists tab. Lists every Artist entity in the library.
/// Tapping a row pushes `ArtistDetailView` so the user can see the
/// artist's albums + songs.
@MainActor
struct ArtistsView: View {

    @Query(sort: [SortDescriptor(\Artist.name, order: .forward)])
    private var artists: [Artist]

    var body: some View {
        Group {
            let header = "Artist name (\(artists.count))"
            if artists.isEmpty {
                EmptyState(
                    title: "No artists yet",
                    message: "Once you import music, every performer in your library will show up here.",
                    icon: {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60, weight: .light))
                    }
                )
            } else {
                artistsList(header: header)
            }
        }
        .background(ColorTokens.canvas)
    }

    private func artistsList(header: String) -> some View {
        List {
            Section {
                sortChip(header: header)
                    .listRowBackground(ColorTokens.canvas)
            }
            Section {
                ForEach(artists) { artist in
                    NavigationLink(value: artist) {
                        ArtistRow(artist: artist)
                    }
                    .listRowBackground(ColorTokens.canvas)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sortChip(header: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.up.arrow.down")
            Text(header)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .font(Typography.subhead)
        .foregroundStyle(ColorTokens.textPrimary)
        .padding(.vertical, Spacing.s)
    }
}
