import SwiftUI
import SwiftData

/// Library tab — Songs / Artists / Albums / Source.
@MainActor
struct LibraryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var sortKey: LibrarySortKey = .artistName
    @State private var direction: SortDirection = .ascending
    @State private var showingSortMenu = false
    @State private var selectedTab: LibraryListTab = .songs
    @State private var presentingNowPlaying = false

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var songInfoTarget: Song?

    @Query private var allSongs: [Song]

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                tabStrip
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Library")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Songs or artists"
            )
            .task(id: searchText) {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                debouncedSearchText = searchText
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.m) {
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
                    totalSongs: allSongs.count
                )
            }
            .sheet(item: $songInfoTarget) { song in
                SongInfoSheet(song: song)
                    .modelContainer(modelContext.container)
            }
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(artist: artist)
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .task {
                if libraryService == nil {
                    libraryService = LibraryService(context: modelContext)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Library")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: Spacing.s) {
            ForEach(LibraryListTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.label)
                        .font(Typography.subhead)
                        .fontWeight(tab == selectedTab ? .bold : .medium)
                        .foregroundStyle(
                            tab == selectedTab ? ColorTokens.appAccent : ColorTokens.textSecondary
                        )
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(tab == selectedTab ? ColorTokens.appAccent.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .songs:    songsTab
        case .artists:  ArtistsView()
        case .albums:   AlbumsView()
        case .source:   SourceView()
        }
    }

    private var songsTab: some View {
        SongsListView(
            sortDescriptor: Song.defaultSort(for: sortKey, direction: direction),
            searchText: debouncedSearchText,
            onSongInfo: { song in songInfoTarget = song },
            onToggleFavorite: { song in toggleFavorite(song) },
            onDelete: { song in libraryService?.delete(song) },
            onShuffle: shuffleAll,
            onPlayAll: playAll,
            onOpenSortMenu: { showingSortMenu = true }
        )
    }

    // MARK: - Actions

    private func shuffleAll() {
        let order = allSongs.shuffled()
        guard let service = libraryService else { return }
        let requests = service.playbackRequests(for: order)
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func playAll() {
        guard let service = libraryService else { return }
        let requests = service.playbackRequests(for: allSongs)
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func toggleFavorite(_ song: Song) {
        libraryService?.toggleFavorite(song)
    }
}

// MARK: - Sort descriptor factory

extension Song {
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
