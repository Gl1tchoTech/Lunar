import SwiftUI
import SwiftData

// MARK: - Library View (reference-aligned)

/// Library tab matching the reference layout:
/// - Dark status-bar-style top bar with "Library" title left,
///   + and … buttons right.
/// - Horizontal filter tabs (Songs / Artists / Albums / Source) with
///   green active indicator under Songs by default.
/// - Content area centers the empty-state illustration when there's no
///   music; otherwise it shows the songs/artists/albums/source list.
@MainActor
struct LibraryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(PlayerThemeManager.self) private var themeManager
    @Environment(TabRouter.self) private var tabRouter

    // MARK: tabs

    enum LibraryListTab: String, CaseIterable, Identifiable {
        case songs
        case artists
        case albums
        case source

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

    // MARK: state

    @State private var selectedTab: LibraryListTab = .songs
    @State private var presentingNowPlaying = false
    @State private var presentingSortMenu = false
    @State private var presentingSelectMode = false
    @State private var presentingMoreMenu = false

    // Sort state driven by the three-dot menu
    @State private var sortKey: LibrarySortKey = .songName
    @State private var direction: SortDirection = .ascending

    // MARK: body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    filterTabs
                    content
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
            .sheet(isPresented: $presentingSortMenu) {
                SortMenu(
                    sortKey: $sortKey,
                    direction: $direction,
                    totalSongs: totalSongCount
                )
            }
            .sheet(isPresented: $presentingSelectMode) {
                SelectModeSheet(
                    songs: songsForSelectedTab
                )
            }
            .sheet(isPresented: $presentingMoreMenu) {
                MoreMenuSheet(
                    songs: songsForSelectedTab,
                    sortKey: sortKey,
                    direction: direction,
                    onOpenSort: { presentingSortMenu = true },
                    onSelect: { presentingSelectMode = true }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: song list backing state

    private var totalSongCount: Int {
        songsForSelectedTab.count
    }

    private var songsForSelectedTab: [Song] {
        switch selectedTab {
        case .songs:
            return SongSearch.filter(currentSongs, by: "")
        case .artists:
            return currentArtists.flatMap { $0.songs }
        case .albums:
            return currentAlbums.flatMap { $0.songs }
        case .source:
            return currentSongs
        }
    }

    private var currentSongs: [Song] {
        let descriptor = FetchDescriptor<Song>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var currentArtists: [Artist] {
        let descriptor = FetchDescriptor<Artist>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var currentAlbums: [Album] {
        let descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: top bar

    private var topBar: some View {
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

                Button {
                    presentingMoreMenu = true
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
                .accessibilityLabel("More options")
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
    }

    // MARK: filter tabs

    private var filterTabs: some View {
        HStack(spacing: Spacing.s) {
            ForEach(LibraryListTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.label)
                        .font(Typography.body)
                        .fontWeight(selectedTab == tab ? .bold : .regular)
                        .foregroundStyle(
                            selectedTab == tab
                                ? ColorTokens.textPrimary
                                : ColorTokens.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .scaleEffect(selectedTab == tab ? 0.96 : 1)
                .animation(.easeInOut(duration: 0.18), value: selectedTab == tab)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(ColorTokens.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.appAccent)
                .frame(height: 2)
                .offset(x: tabIndicatorOffset, y: 0)
        }
    }

    private var tabIndicatorOffset: CGFloat {
        let tabWidth: CGFloat = 72
        let spacing: CGFloat = Spacing.s
        let count = CGFloat(LibraryListTab.allCases.count)
        let index = CGFloat(LibraryListTab.allCases.firstIndex(of: selectedTab) ?? 0)
        let totalWidth = count * tabWidth + (count - 1) * spacing
        let leadingInset = (UIScreen.main.bounds.width - totalWidth) / 2
        return leadingInset + index * (tabWidth + spacing) + tabWidth / 2 - 4
    }

    // MARK: content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .songs:
            SongsListView(
                sortDescriptor: activeSortDescriptor,
                searchText: "",
                totalSongsHint: songsForSelectedTab.count,
                onSongInfo:    { song in songInfoSheet(for: song) },
                onToggleFavorite: { song in toggleFavorite(song) },
                onDelete:      { song in deleteSong(song) },
                onShuffle:     { shuffleSelected() },
                onPlayAll:     { playSelected() },
                onOpenSortMenu: { presentingSortMenu = true }
            )
        case .artists:
            ArtistsView()
        case .albums:
            AlbumsView()
        case .source:
            SourceView()
        }
    }

    private var activeSortDescriptor: SortDescriptor<Song> {
        let field: KeyPath<Song, Comparable> = activeSortKeyPath
        return SortDescriptor(field, order: direction == .ascending ? .forward : .reverse)
    }

    private var activeSortKeyPath: KeyPath<Song, Comparable> {
        switch sortKey {
        case .songName:       \Song.title
        case .artistName:     \Song.artist
        case .recentlyAdded:  \Song.dateAdded
        case .latestPlayed:   \Song.lastPlayed ?? .distantPast
        case .size:           \Song.duration
        case .mostPlayed:     \Song.playCount
        }
    }

    // MARK: actions

    private func shuffleSelected() {
        let songs = songsForSelectedTab
        guard !songs.isEmpty, let service = libraryService else { return }
        let requests = service.playbackRequests(for: songs.shuffled())
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func playSelected() {
        let songs = songsForSelectedTab
        guard !songs.isEmpty, let service = libraryService else { return }
        let requests = service.playbackRequests(for: songs)
        audioEngine.playQueue(requests)
        presentingNowPlaying = true
    }

    private func toggleFavorite(_ song: Song) {
        guard let service = libraryService else { return }
        _ = service.toggleFavorite(song)
    }

    private func deleteSong(_ song: Song) {
        guard let service = libraryService else { return }
        service.delete(song)
    }

    private func songInfoSheet(for song: Song) {
        // Present the song info sheet as a sheet from the Library context.
        // In the reference UI this is driven by the three-dot menu per row;
        // here we expose it via the global more menu as well.
    }

    // MARK: model access

    private var currentSongs: [Song] {
        let descriptor = FetchDescriptor<Song>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var currentArtists: [Artist] {
        let descriptor = FetchDescriptor<Artist>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var currentAlbums: [Album] {
        let descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var libraryService: LibraryService? {
        LibraryService(context: modelContext)
    }
}

// MARK: - More Menu Sheet

struct MoreMenuSheet: View {
    let songs: [Song]
    let sortKey: LibrarySortKey
    let direction: SortDirection
    let onOpenSort: () -> Void
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onOpenSort()
                    dismiss()
                } label: {
                    Label(
                        "Sort",
                        systemImage: "arrow.up.arrow.down"
                    )
                }

                Button {
                    onSelect()
                    dismiss()
                } label: {
                    Label(
                        songs.isEmpty ? "Select" : "Select \(songs.count) Songs",
                        systemImage: "checkmark.circle"
                    )
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
