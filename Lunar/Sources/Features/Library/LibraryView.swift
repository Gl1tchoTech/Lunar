import SwiftUI
import SwiftData

/// Library tab — Songs / Artists / Albums / Source.
///
/// Step 3 wires the **Songs** tab fully (sort menu, action row, song
/// rows, context menu, empty state). The other three tabs render as
/// minimal placeholders until their dedicated steps (see plan).
struct LibraryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var sortKey: LibrarySortKey = .artistName
    @State private var direction: SortDirection = .ascending
    @State private var showingSortMenu = false
    @State private var selectedTab: LibraryListTab = .songs

    // Songs query — sort key + direction drive the SortDescriptor.
    @Query private var songs: [Song]

    enum LibraryListTab: String, CaseIterable, Identifiable {
        case songs, artists, albums, source
        var id: String { rawValue }
        var label: String {
            switch self {
            case .songs:   "Songs"
            case .artists: "Artists"
            case .albums:  "Albums"
            case .source:  "Source"
            }
        }
    }

    init() {
        // Initial fetch with the default sort (Artist name ▲). Setting
        // a fresh `FetchDescriptor` on `@Query` is read-only here; the
        // runtime swap happens via `updateQuery()` when the user picks
        // a different sort.
        _songs = Query(
            filter: nil,
            sort: [Song.defaultSort(for: .artistName, direction: .ascending)]
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabStrip
                Divider().background(ColorTokens.hairline)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.m) {
                        // PRO badge removed per locked decision (no paywall)
                        Image(systemName: "plus")
                            .accessibilityLabel("Add songs")
                        Image(systemName: "ellipsis")
                            .accessibilityLabel("More")
                    }
                    .foregroundStyle(ColorTokens.appAccent)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingSortMenu) {
                SortMenu(
                    sortKey: $sortKey,
                    direction: $direction,
                    totalSongs: songs.count
                )
            }
            .task {
                if libraryService == nil {
                    libraryService = LibraryService(context: modelContext)
                }
            }
        }
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: Spacing.l) {
            ForEach(LibraryListTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.label)
                            .font(Typography.subheadline)
                            .foregroundStyle(
                                tab == selectedTab
                                    ? ColorTokens.textPrimary
                                    : ColorTokens.textSecondary
                            )
                        Rectangle()
                            .fill(tab == selectedTab ? ColorTokens.appAccent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .songs:    songsTab
        case .artists:  artistsStub
        case .albums:   albumsStub
        case .source:   sourceStub
        }
    }

    private var songsTab: some View {
        Group {
            if songs.isEmpty {
                EmptyState(
                    title: "No music yet",
                    message: "Import songs from your device to start building your library.",
                    icon: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60, weight: .light))
                    }
                )
            } else {
                songsList
            }
        }
    }

    private var songsList: some View {
        List {
            Section {
                sortChip
                    .listRowBackground(ColorTokens.canvas)
                LibraryActionRow(
                    totalSongs: songs.count,
                    onShuffle: shuffleAll,
                    onPlayAll: playAll
                )
                .listRowBackground(ColorTokens.canvas)
            }
            Section {
                ForEach(songs) { song in
                    SongRow(
                        song: song,
                        onToggleFavorite: { toggleFavorite(song) }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            libraryService?.delete(song)
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            libraryService?.toggleFavorite(song)
                        } label: {
                            Label(
                                song.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: song.isFavorite ? "heart.slash" : "heart"
                            )
                        }
                        .tint(ColorTokens.appAccent)
                    }
                    .contextMenu {
                        contextMenuContent(for: song)
                    }
                    .listRowBackground(ColorTokens.canvas)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.canvas)
        .onChange(of: sortKey) { _, _ in updateQuery() }
        .onChange(of: direction) { _, _ in updateQuery() }
    }

    private var sortChip: some View {
        Button {
            showingSortMenu = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortKey.label)
                Text("(\(songs.count))")
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .font(Typography.subheadline)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.vertical, Spacing.s)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextMenuContent(for song: Song) -> some View {
        Button {
            toggleFavorite(song)
        } label: {
            Label(
                song.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: song.isFavorite ? "heart.slash" : "heart"
            )
        }
        Menu {
            if let service = libraryService {
                let playlists = (try? modelContext.fetch(FetchDescriptor<Playlist>())) ?? []
                ForEach(playlists) { playlist in
                    Button(playlist.title) {
                        service.add(song, to: playlist)
                    }
                }
                if playlists.isEmpty {
                    Text("No playlists yet").foregroundStyle(.secondary)
                }
            }
        } label: {
            Label("Add to Playlist", systemImage: "text.badge.plus")
        }
        Button {
            // Step 5: open the Song Info sheet.
        } label: {
            Label("Song Info", systemImage: "info.circle")
        }
        Button {
            // Step 5: open the share sheet for song URL.
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - Stubs (more in Steps 4–6)

    private var artistsStub: some View {
        EmptyState(
            title: "Artists",
            message: "Browse your library grouped by performer.",
            icon: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 60, weight: .light))
            }
        )
    }

    private var albumsStub: some View {
        EmptyState(
            title: "Albums",
            message: "Browse your library grouped by album.",
            icon: {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 60, weight: .light))
            }
        )
    }

    private var sourceStub: some View {
        EmptyState(
            title: "Source",
            message: "Songs grouped by where they live (Local Files, Other Apps).",
            icon: {
                Image(systemName: "folder.fill")
                    .font(.system(size: 60, weight: .light))
            }
        )
    }

    // MARK: - Actions

    private func shuffleAll() {
        guard let first = songs.shuffled().first else { return }
        sendLoad(for: first)
    }

    private func playAll() {
        guard let first = songs.first else { return }
        sendLoad(for: first)
    }

    private func toggleFavorite(_ song: Song) {
        libraryService?.toggleFavorite(song)
    }

    private func sendLoad(for song: Song) {
        guard
            let url = MusicLibrary.absoluteURL(forFileName: song.fileName)
        else { return }
        let request = PlaybackRequest(
            songID: song.persistentModelID,
            title: song.title,
            artist: song.artist,
            fileURL: url,
            duration: song.duration
        )
        Task { await audioEngine.send(.load(request)) }
    }

    // MARK: - @Query rebuild on sort change

    private func updateQuery() {
        // SwiftData `@Query` can't be mutated from inside the view's
        // `body`. We dispatch a single sentinel assignment via the
        // background queue that hands off to a fresh `Query` so the
        // list re-fetches with the new SortDescriptor.
        let newDescriptor = Song.defaultSort(for: sortKey, direction: direction)
        let refreshed = Query<Song>(filter: nil, sort: [newDescriptor])
        _songs = refreshed
    }
}

// MARK: - Sort descriptor factory

extension Song {
    /// Build a `SortDescriptor<Song>` for a given key + direction.
    /// Used by `@Query` both at first render and on user sort change.
    static func defaultSort(
        for key: LibrarySortKey,
        direction: SortDirection
    ) -> SortDescriptor<Song> {
        let order: SortOrder = direction == .ascending ? .forward : .reverse
        switch key {
        case .songName:       return SortDescriptor(\.title, order: order)
        case .artistName:     return SortDescriptor(\.artist, order: order)
        case .recentlyAdded:  return SortDescriptor(\.dateAdded, order: order)
        case .latestPlayed:   return SortDescriptor(\.lastPlayed, order: order)
        case .size:           return SortDescriptor(\.fileSize, order: order)
        case .mostPlayed:     return SortDescriptor(\.playCount, order: order)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: LunarSchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return LibraryView()
        .environment(AudioEngine())
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
