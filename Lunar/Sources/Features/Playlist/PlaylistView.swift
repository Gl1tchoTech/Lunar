import SwiftUI
import SwiftData

/// Playlist tab with MeloPlayer styling.
@MainActor
struct PlaylistView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @State private var libraryService: LibraryService?
    @State private var showingCreateDialog = false
    @State private var newPlaylistName = ""

    @State private var navPath: [PlaylistNavEnum] = []

    @State private var mostPlayed: [Song] = []
    @State private var recentlyPlayed: [Song] = []
    @State private var favorites: [Song] = []

    @Query(sort: [SortDescriptor(\Playlist.dateCreated, order: .forward)])
    private var playlists: [Playlist]

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    smartTilesRow
                    localPlaylistHeader
                    CreateNewRow {
                        showingCreateDialog = true
                    }
                    if !playlists.isEmpty {
                        LazyVStack(spacing: Spacing.m) {
                            ForEach(playlists) { playlist in
                                NavigationLink(value: PlaylistNavEnum.regular(playlist)) {
                                    LocalPlaylistRow(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        emptyHint
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, 140)
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
            .task {
                if libraryService == nil {
                    libraryService = LibraryService(context: modelContext)
                }
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

    private var header: some View {
        HStack {
            Text("Playlist")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
    }

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

    private var localPlaylistHeader: some View {
        HStack(spacing: Spacing.xs) {
            Text("My Local Playlist (\(playlists.count))")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
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

// MARK: - Smart Playlist Route

enum SmartPlaylistRoute: Hashable {
    case favorites([Song])
    case mostPlayed([Song])
    case recentlyPlayed([Song])

    var kind: SmartPlaylistTile.Kind {
        switch self {
        case .favorites:      return .favorites
        case .mostPlayed:     return .mostPlayed
        case .recentlyPlayed: return .recentlyPlayed
        }
    }

    var songs: [Song] {
        switch self {
        case .favorites(let songs),
             .mostPlayed(let songs),
             .recentlyPlayed(let songs):
            return songs
        }
    }
}

extension SmartPlaylistTile.Kind {
    var favoritesRouteStyle: PlaylistDetailView.HeroStyle {
        switch self {
        case .favorites:      return .heart
        case .mostPlayed:     return .icon(systemName: "music.note")
        case .recentlyPlayed: return .icon(systemName: "clock")
        }
    }
}

// MARK: - Create New Row

struct CreateNewRow: View {

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ColorTokens.appAccent)

                Text("Create New")
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ColorTokens.surface)
            )
        }
        .buttonStyle(.plain)
    }
}
