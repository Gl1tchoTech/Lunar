import SwiftUI
import SwiftData

/// **Song Info** — full bottom-of-the-song sheet. Surfaces identity,
/// audio metadata, file location, and the primary song actions
/// (Add to Playlist · Toggle Favorite · Share). Mirrors the inset-
/// grouped Form style already used by `AboutView` and the Settings
/// destinations so the visual language stays consistent.
///
/// Presented from `SongRow.contextMenu` -> "Song Info" via the host
/// view's `.sheet(isPresented:)` modifier (each hosting surface
/// (Library / Playlist detail) keeps its own `@State`.
struct SongInfoSheet: View {

    let song: Song

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var libraryService: LibraryService?
    @State private var presentingAddSuccess: Bool = false
    @State private var lastAddedPlaylistName: String = ""

    /// Cached lookup so the "Lyrics" section knows whether to render
    /// a status row or just an "Open" button. Mirrors `LyricsLibrary`'s
    /// contract without coupling the sheet to it directly.
    private var hasLyrics: Bool {
        song.lyricsFileName?.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                metadataSection
                fileSection
                lyricsSection
                actionsSection
            }
            .scrollContentBackground(.hidden)
            .background(ColorTokens.canvas)
            .navigationTitle("Song Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Added to \(lastAddedPlaylistName)",
                isPresented: $presentingAddSuccess
            ) {
                Button("OK", role: .cancel) {}
            }
            .task {
                if libraryService == nil {
                    libraryService = LibraryService(context: modelContext)
                }
            }
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Identity") {
            LabeledContent("Title",  value: song.title)
            LabeledContent("Artist", value: song.artist)
            if let album = song.albumTitle, !album.isEmpty {
                LabeledContent("Album", value: album)
            }
            if let trackNumber = song.trackNumber {
                LabeledContent("Track",
                               value: String(trackNumber))
            }
            if let year = song.year {
                LabeledContent("Year", value: String(year))
            }
        }
    }

    private var metadataSection: some View {
        Section("Audio") {
            if let format = song.format {
                LabeledContent("Format",     value: format)
            }
            if let bitrate = song.bitrate {
                LabeledContent("Bitrate",
                               value: "\(bitrate) kbps")
            }
            if let sampleRate = song.sampleRate {
                LabeledContent("Sample Rate",
                               value: "\(Int(sampleRate)) Hz")
            }
            if let bitDepth = song.bitDepth {
                LabeledContent("Bit Depth",
                               value: "\(bitDepth)-bit")
            }
            LabeledContent("Duration",
                           value: durationString)
            LabeledContent("File Size",
                           value: fileSizeString)
        }
    }

    private var fileSection: some View {
        Section("File") {
            LabeledContent("Name") {
                Text(song.fileName)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            LabeledContent("Plays") {
                Text("\(song.playCount)")
                    .foregroundStyle(ColorTokens.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var lyricsSection: some View {
        Section("Lyrics") {
            if hasLyrics {
                LabeledContent("Status") {
                    Text("Synced (.lrc)")
                        .foregroundStyle(ColorTokens.success)
                }
            } else {
                LabeledContent("Status") {
                    Text("Not imported")
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Text("Drop a `.lrc` file from any source app into the Import flow to attach lyrics to this song.")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            addToPlaylistRow
            favoriteToggleRow
            if let url = MusicLibrary.absoluteURL(forFileName: song.fileName) {
                ShareLink(item: url) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    @ViewBuilder
    private var addToPlaylistRow: some View {
        if let service = libraryService {
            Menu {
                let playlists = (try? modelContext.fetch(
                    FetchDescriptor<Playlist>(
                        sortBy: [SortDescriptor(\.dateCreated, order: .forward)]
                    )
                )) ?? []
                if playlists.isEmpty {
                    Text("No playlists yet")
                } else {
                    ForEach(playlists) { playlist in
                        Button(playlist.title) {
                            service.add(song, to: playlist)
                            lastAddedPlaylistName = playlist.title
                            presentingAddSuccess = true
                        }
                    }
                }
            } label: {
                Label("Add to Playlist", systemImage: "text.badge.plus")
            }
        } else {
            Label("Add to Playlist", systemImage: "text.badge.plus")
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private var favoriteToggleRow: some View {
        Button {
            libraryService?.toggleFavorite(song)
        } label: {
            Label(
                song.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: song.isFavorite ? "heart.slash" : "heart"
            )
            .foregroundStyle(
                song.isFavorite
                    ? ColorTokens.destructive
                    : ColorTokens.textPrimary
            )
        }
    }

    // MARK: - Formatters

    private var durationString: String {
        let total = Int(song.duration.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private var fileSizeString: String {
        ByteCountFormatter.string(
            fromByteCount: song.fileSize,
            countStyle: .file
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: LunarSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let song = Song(
        title: "Sample Track",
        artist: "Gl1tcho",
        albumTitle: "Demo Album",
        trackNumber: 1,
        year: 2026,
        duration: 213,
        fileName: "demo-uuid.mp3",
        fileSize: 4_200_000,
        format: "MP3",
        bitrate: 320,
        sampleRate: 44_100,
        bitDepth: 16
    )
    context.insert(song)
    return SongInfoSheet(song: song)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
