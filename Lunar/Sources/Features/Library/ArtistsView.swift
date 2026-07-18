import SwiftUI
import SwiftData

/// Library — Artists tab.
@MainActor
struct ArtistsView: View {

    @Query(sort: [SortDescriptor(\Artist.name, order: .forward)])
    private var artists: [Artist]

    var body: some View {
        Group {
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
                artistsList
            }
        }
        .background(ColorTokens.canvas)
    }

    private var artistsList: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                HStack {
                    Text("\(artists.count) artist\(artists.count == 1 ? "" : "s")")
                        .font(Typography.subhead)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)

                ForEach(artists) { artist in
                    NavigationLink(value: artist) {
                        ArtistRow(artist: artist)
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
