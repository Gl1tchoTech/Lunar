import SwiftUI
import SwiftData

/// Library — Artist detail. Pushes when a row in `ArtistsView` is tapped.
/// Shows the artist's songs and the album(s) they're credited on.
@MainActor
struct ArtistDetailView: View {

    let artist: Artist

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var presentingNowPlaying = false

    var body: some View {
        Group {
            if artist.songs.isEmpty {
                EmptyState(
                    title: "No songs yet",
                    message: "This artist has no songs in your library.",
                    icon: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50, weight: .light))
                    }
                )
            } else {
                artistList
            }
        }
        .background(ColorTokens.canvas)
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $presentingNowPlaying) {
            NowPlayingView()
                .environment(audioEngine)
        }
        .task {
            if libraryService == nil {
                libraryService = LibraryService(context: modelContext)
            }
        }
    }

    private var artistList: some View {
        List {
            // Albums by this artist
            let albums = uniqueAlbums()
            if !albums.isEmpty {
                Section("Albums (\(albums.count))") {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            AlbumRow(album: album)
                        }
                        .listRowBackground(ColorTokens.canvas)
                    }
                }
            }

            Section("Songs (\(artist.songs.count))") {
                ForEach(artist.songs) { song in
                    SongRow(song: song, onToggleFavorite: {
                        libraryService?.toggleFavorite(song)
                    })
                    .listRowBackground(ColorTokens.canvas)
                    .onTapGesture { tapped(song) }
                }
            }

            Section {
                LibraryActionRow(
                    totalSongs: artist.songs.count,
                    onShuffle: { playAll(shuffled: true) },
                    onPlayAll: { playAll(shuffled: false) }
                )
                .listRowBackground(ColorTokens.canvas)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private func uniqueAlbums() -> [Album] {
        let dict = Dictionary(grouping: artist.songs, by: { $0.albumTitle ?? "—" })
        return dict.compactMap { _, songs in songs.first?.album }
    }

    private func playAll(shuffled: Bool) {
        let list = shuffled ? artist.songs.shuffled() : artist.songs
        guard let service = libraryService else { return }
        let requests = service.playbackRequests(for: list)
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func tapped(_ song: Song) {
        guard let service = libraryService else { return }
        let (requests, startIndex) = service.playbackRequests(
            for: artist.songs,
            startingAt: song.persistentModelID
        )
        audioEngine.playQueue(requests, startIndex: startIndex)
        presentingNowPlaying = true
    }
}
