import SwiftUI
import SwiftData

/// Library — Album detail. Pushes when a row in `AlbumsView` is tapped.
/// Shows the album's composing songs. Tapping a song plays it via
/// `LibraryService.playbackRequests(_:)` and queues the rest.
@MainActor
struct AlbumDetailView: View {

    let album: Album

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var presentingNowPlaying = false

    var body: some View {
        Group {
            if album.songs.isEmpty {
                EmptyState(
                    title: "Empty album",
                    message: "This album has no songs in your library yet.",
                    icon: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50, weight: .light))
                    }
                )
            } else {
                albumList
            }
        }
        .background(ColorTokens.canvas)
        .navigationTitle(album.title)
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

    private var albumList: some View {
        List {
            Section {
                LibraryActionRow(
                    totalSongs: album.songs.count,
                    onShuffle: { playAll(shuffled: true) },
                    onPlayAll: { playAll(shuffled: false) }
                )
                .listRowBackground(ColorTokens.canvas)
            }
            Section {
                ForEach(album.songs) { song in
                    SongRow(song: song, onToggleFavorite: {
                        libraryService?.toggleFavorite(song)
                    })
                    .listRowBackground(ColorTokens.canvas)
                    .onTapGesture { tapped(song) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func playAll(shuffled: Bool) {
        let list = shuffled ? album.songs.shuffled() : album.songs
        guard let service = libraryService else { return }
        let requests = service.playbackRequests(for: list)
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func tapped(_ song: Song) {
        guard let service = libraryService else { return }
        let (requests, startIndex) = service.playbackRequests(
            for: album.songs,
            startingAt: song.persistentModelID
        )
        audioEngine.playQueue(requests, startIndex: startIndex)
        presentingNowPlaying = true
    }
}
