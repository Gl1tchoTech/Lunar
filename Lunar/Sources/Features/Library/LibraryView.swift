import SwiftUI
import SwiftData

/// Library tab — Songs / Artists / Albums / Source.
///
/// Step 3 wired the **Songs** tab fully (sort menu, action row, song
/// rows, context menu, empty state). The other three tabs render as
/// minimal placeholders until their dedicated steps (see plan).
///
/// **Tier 5** upgrades the Songs tab:
///
/// - **Search** — `.searchable` with a 250 ms debounce via
///   `.task(id: searchText)`. The actual filter lives in
///   `SongsListView` (which owns its bound `@Query`) so a sort change
///   re-binds cleanly without fighting iOS 17 SwiftData's
///   "can't reassign `_songs`" trap.
/// - **Song Info** — long-press (`contextMenu`) or single-tap on a row
///   sets `songInfoTarget`; `.sheet(item:)` presents `SongInfoSheet`.
///   Using `.sheet(item: $target)` instead of `isPresented` + parallel
///   song id avoids the typical two-state desync.
///
/// The current tab, sort key, and search copy live here so other tabs
/// don't accidentally read the sort or search bar by accident.
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

    // Tier 5 — search bar (debounced) + Song Info sheet hosting.

    /// Live search text. Drives `.searchable` directly so the search
    /// bar feels instant; `debouncedSearchText` follows it 250 ms
    /// later so we don't churn the @Query on every keystroke.
    @State private var searchText: String = ""

    /// Debounced (Tier 5 — 250 ms via `.task(id:)`) copy. The
    /// `SongsListView` filters against this, not `searchText`.
    @State private var debouncedSearchText: String = ""

    /// `Song` is `Identifiable` via SwiftData's `@Model` →
    /// `PersistentModel` conformance. A single `@State` here is enough
    /// — `.sheet(item: $songInfoTarget)` presents when non-nil + the
    /// sheet's `dismiss()` clears it. **(Replaces the old `.isPresented
    /// + selectedSong` double state that used to drift.)**
    @State private var songInfoTarget: Song?

    /// Parallel @Query used purely for counts (SortMenu shows
    /// "N songs"). Render order lives in `SongsListView` so the
    /// sort-bound SortDescriptor can rebind its inner @Query without
    /// mutating this one.
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
                tabStrip
                Divider().background(ColorTokens.hairline)
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
                // 250 ms debounce. `.task(id:)` cancels the prior task
                // on every change so the next keystroke simply starts a
                // new timer — no Combine plumbing required, and no
                // manual cancel logic.
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                debouncedSearchText = searchText
            }
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
            .safeAreaInset(edge: .bottom) {
                MiniPlayer(isPresented: $presentingNowPlaying)
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

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: Spacing.l) {
            ForEach(LibraryListTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.label)
                            .font(Typography.subhead)
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
        case .artists:  ArtistsView()
        case .albums:   AlbumsView()
        case .source:   SourceView()
        }
    }

    /// Songs tab body is now a `SongsListView` — owns the sort-bound
    /// `@Query` and the filter. LibraryView just supplies the sort
    /// descriptor + the live debounced search text + action closures.
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
}

// MARK: - Sort descriptor factory

extension Song {
    /// Build a `SortDescriptor<Song>` for a given key + direction.
    /// Used by `SongsListView` both at first render and on user sort
    /// change (a new descriptor → `init` re-binds the inner @Query).
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
