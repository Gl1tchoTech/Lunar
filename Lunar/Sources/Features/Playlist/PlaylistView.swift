import SwiftUI
import SwiftData

/// Playlist tab. Layout mirrors reference:
/// 1. Three smart-playlist tiles in a horizontally-scrolling row
///    (`My Favorites` · `Most Played` · `Recently Played`)
/// 2. `↑↓ My Local Playlist (N)` section header
/// 3. Big lime "+" Create New row
/// 4. List of user playlists
///
/// All pushes go to `PlaylistDetailView` with the right hero style.
struct PlaylistView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var presentingNowPlaying = false
    @State private var showingCreateDialog = false
    @State private var newPlaylistName = ""

    /// Path-bound `NavigationStack` so the smart-playlist tiles can
    /// `append(.mostPlayed)` and `append(.recentlyPlayed)` without
    /// having to wrap the result in `NavigationLink`.
    @State private var navPath: [PlaylistNavEnum] = []

    // Smart-tile state, loaded once via `.task` instead of inside
    // `body` (which would re-run a synchronous SwiftData fetch every
    // render and stutter the UI).
    @State private var mostPlayed: [Song] = []
    @State private var recentlyPlayed: [Song] = []
    /// Tier 5 — `My Favorites` smart-playlist state. Source is
    /// `LibraryService.favoriteSongs()` (predicate on `Song.isFavorite`).
    @State private var favorites: [Song] = []

    @Query(sort: [SortDescriptor(\Playlist.dateCreated, order: .forward)])
    private var playlists: [Playlist]

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    smartTilesRow
                    localPlaylistHeader
                    CreateNewRow {
                        showingCreateDialog = true
                    }
                    if !playlists.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(playlists) { playlist in
                                NavigationLink(value: PlaylistNavEnum.regular(playlist)) {
                                    LocalPlaylistRow(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(ColorTokens.canvas)
                    } else {
                        emptyHint
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, 96) // leave room for MiniPlayer
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Playlist")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: PlaylistNavEnum.self) { entry in
                switch entry {
                case .regular(let playlist):
                    PlaylistDetailView(
                        title: playlist.title,
                        subtitle: detailSubtitle(for: playlist),
                        heroStyle: playlist.title == "My Favorites"
                            ? .heart
                            : .icon(systemName: "music.note"),
                        songs: playlist.songs.sorted(by: { $0.dateAdded > $1.dateAdded })
                    )
                case .smart(let route):
                    PlaylistDetailView(
                        title: route.kind.title,
                        subtitle: subtitle(forSongs: route.songs),
                        heroStyle: route.kind.favoritesRouteStyle,
                        songs: route.songs
                    )
                }
            }
            .alert("New Playlist", isPresented: $showingCreateDialog) {
                TextField("Title", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Save") {
                    let trimmed = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    libraryService?.createPlaylist(title: trimmed)
                    newPlaylistName = ""
                }
            }
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
            .safeAreaInset(edge: .bottom) {
                MiniPlayer(isPresented: $presentingNowPlaying)
            }
            .task {
                if libraryService == nil {
                    libraryService = LibraryService(context: modelContext)
                }
                // Hydrate smart-tile state ONCE. Subsequent renders
                // read from `mostPlayed` / `recentlyPlayed` instead of
                // re-running a SwiftData fetch every time `body` runs.
                mostPlayed = libraryService?.mostPlayedSongs() ?? []
                recentlyPlayed = libraryService?.recentlyPlayedSongs() ?? []
                favorites = libraryService?.favoriteSongs() ?? []
            }
        }
    }

    enum PlaylistNavEnum: Hashable {
        case regular(Playlist)
        case smart(SmartPlaylistRoute)
    }

    // MARK: - Smart tiles

    /// Tier 5 — three smart tiles now (`My Favorites` joined the
    /// existing pair). Wrapped in a horizontal scroll so the layout
    /// doesn't get cramped on smaller iPhone widths (three ≥ 140 pt
    /// tiles with 16 pt gaps is ≈ 452 pt — wider than an iPhone 15
    /// portrait). Each tile is `.frame(width: 170)` so the row stays
    /// predictable regardless of `maxWidth: .infinity` on the tile.
    private var smartTilesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.m) {
                SmartPlaylistTile(
                    kind: .favorites,
                    songCount: favorites.count,
                    totalDuration: favorites.reduce(0.0) { $0 + $1.duration },
                    action: {
                        navPath.append(.smart(.favorites(favorites)))
                    }
                )
                .frame(width: 170)
                SmartPlaylistTile(
                    kind: .mostPlayed,
                    songCount: mostPlayed.count,
                    totalDuration: mostPlayed.reduce(0.0) { $0 + $1.duration },
                    action: {
                        navPath.append(.smart(.mostPlayed(mostPlayed)))
                    }
                )
                .frame(width: 170)
                SmartPlaylistTile(
                    kind: .recentlyPlayed,
                    songCount: recentlyPlayed.count,
                    totalDuration: recentlyPlayed.reduce(0.0) { $0 + $1.duration },
                    action: {
                        navPath.append(.smart(.recentlyPlayed(recentlyPlayed)))
                    }
                )
                .frame(width: 170)
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Local playlist header + rows

    private var localPlaylistHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.up.arrow.down")
            Text("My Local Playlist (\(playlists.count))")
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .font(Typography.subhead)
        .foregroundStyle(ColorTokens.textPrimary)
        .padding(.top, Spacing.m)
    }

    private var emptyHint: some View {
        EmptyState(
            title: "No playlists yet",
            message: "Create your first playlist to organize your music.",
            icon: {
                Image(systemName: "music.note.tv")
                    .font(.system(size: 50, weight: .light))
            }
        )
        .frame(minHeight: 220)
    }

    // MARK: - Helpers

    private func detailSubtitle(for playlist: Playlist) -> String? {
        let songs = playlist.songs
        let total = songs.reduce(0.0) { $0 + $1.duration }
        let formatted = formatTotal(total)
        return "\(songs.count) song\(songs.count == 1 ? "" : "s") | \(formatted)"
    }

    private func subtitle(forSongs songs: [Song]) -> String {
        let total = songs.reduce(0.0) { $0 + $1.duration }
        return "\(songs.count) song\(songs.count == 1 ? "" : "s") | \(formatTotal(total))"
    }

    private func formatTotal(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = total / 60
        let s = total % 60
        if h > 0 { return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))" }
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - SmartPlaylistRoute

/// Navigator-tag wrapper for the smart-playlist hero tiles.
struct SmartPlaylistRoute: Hashable {
    let kind: SmartPlaylistTile.Kind
    let songs: [Song]
}

// Static factories used from `navPath.append(.smart(.favorites(...)))`.
// Mirrors the same shape as the SmartPlaylistTile.Kind extension
// below so `PlaylistNavEnum.smart(_:)` callers don't need to know
// about the Kind enum.
extension SmartPlaylistRoute {
    static func favorites(_ songs: [Song])      -> SmartPlaylistRoute { .init(kind: .favorites, songs: songs) }
    static func mostPlayed(_ songs: [Song])     -> SmartPlaylistRoute { .init(kind: .mostPlayed, songs: songs) }
    static func recentlyPlayed(_ songs: [Song]) -> SmartPlaylistRoute { .init(kind: .recentlyPlayed, songs: songs) }
}

/// Maps a `SmartPlaylistTile.Kind` to a `PlaylistDetailView.HeroStyle`.
///
/// `My Favorites` uses the heart hero (matches `PlaylistDetailView`'s
/// existing `.heart` enum case + `regular`-route branch logic);
/// `Most Played` and `Recently Played` use their respective gradients.
extension SmartPlaylistTile.Kind {
    var favoritesRouteStyle: PlaylistDetailView.HeroStyle {
        switch self {
        case .favorites:       .heart
        case .mostPlayed:      .gradient(colors: Self.mostPlayed.gradient)
        case .recentlyPlayed:  .gradient(colors: Self.recentlyPlayed.gradient)
        }
    }

    var navHashable: SmartPlaylistRoute {
        // synthesize with empty songs first; the tile callback carries
        // the songs along — see `pushSmartPlaylist(_:)`.
        SmartPlaylistRoute(kind: self, songs: [])
    }
    static func favorites(_ songs: [Song])      -> SmartPlaylistRoute { .init(kind: .favorites, songs: songs) }
    static func mostPlayed(_ songs: [Song])     -> SmartPlaylistRoute { .init(kind: .mostPlayed, songs: songs) }
    static func recentlyPlayed(_ songs: [Song]) -> SmartPlaylistRoute { .init(kind: .recentlyPlayed, songs: songs) }
}

// MARK: - CreateNewRow

private struct CreateNewRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.appAccent)
                        .frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Create New")
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.appAccent)
                Spacer()
            }
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}
