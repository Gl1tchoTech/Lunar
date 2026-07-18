import SwiftUI
import SwiftData

/// Library tab — Songs / Artists / Albums / Source.
@MainActor
struct LibraryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(TabRouter.self) private var tabRouter

    @State private var libraryService: LibraryService?
    @State private var sortKey: LibrarySortKey = .artistName
    @State private var direction: SortDirection = .ascending
    @State private var showingSortMenu = false
    @State private var selectedTab: LibraryListTab = .songs
    @State private var presentingNowPlaying = false

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var songInfoTarget: Song?
    @State private var showingSelectMode = false

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
                customHeader
                tabStrip
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ColorTokens.canvas)
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

    private var customHeader: some View {
        HStack(spacing: Spacing.s) {
            Text("Library")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            HStack(spacing: Spacing.s) {
                Button {
                    tabRouter.selectedTab = .importer
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(ColorTokens.surface)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add songs")

                Menu {
                    Button {
                        searchText = ""
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    Button {
                        showingSelectMode = true
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                    Button {
                        // Feedback stub — could open mail composer in future.
                    } label: {
                        Label("Feedback", systemImage: "envelope")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(ColorTokens.surface)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(LibraryListTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.label)
                            .font(Typography.subhead)
                            .fontWeight(tab == selectedTab ? .bold : .medium)
                            .foregroundStyle(
                                tab == selectedTab ? ColorTokens.textPrimary : ColorTokens.textSecondary
                            )
                        ZStack {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 20, height: 3)
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(ColorTokens.appAccent)
                                    .frame(width: 20, height: 3)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xs)
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
