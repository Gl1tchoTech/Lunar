import SwiftUI
import SwiftData

// MARK: - Playlist view (reference-aligned)

/// Reference-aligned Playlist tab.
///
/// Layout mirrors the PNGs: a "Playlists" title, a horizontal
/// smart-tile row, and a list of imported/playlist rows below.
@MainActor
struct PlaylistView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(TabRouter.self) private var tabRouter

    @State private var showingCreateDialog = false
    @State private var newPlaylistName = ""
    @State private var selectedPlaylist: Playlist?
    @State private var presentingNowPlaying = false

    // Placeholder collections — the reference PNG shows smart tiles
    // plus a small list of local playlists.
    @State private var smartTiles: [SmartPlaylistTileModel] = [
        .favorites(songCount: 0),
        .mostPlayed(songCount: 0),
        .recentlyPlayed(songCount: 0),
    ]
    @State private var localPlaylists: [LocalPlaylistModel] = []

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        titleBar

                        smartTilesRow

                        divider

                        localPlaylistsSection
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
                    .padding(.bottom, 140)
                }
            }
            .navigationBarHidden(true)
            .alert("New Playlist", isPresented: $showingCreateDialog) {
                TextField("Name", text: $newPlaylistName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    createPlaylist()
                }
            } message: {
                Text("Give your playlist a name.")
            }
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: title bar

    private var titleBar: some View {
        HStack {
            Text("Playlists")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            Button {
                showingCreateDialog = true
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
            .accessibilityLabel("Create playlist")
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
    }

    // MARK: smart tiles

    private var smartTilesRow: some View {
        HStack(spacing: Spacing.s) {
            ForEach(smartTiles) { tile in
                SmartTileButton(tile: tile) {
                    tapSmartTile(tile)
                }
            }
        }
    }

    // MARK: local playlists

    private var localPlaylistsSection: some View {
        let hasPlaylists = !localPlaylists.isEmpty
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("All Playlists")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)

            if hasPlaylists {
                VStack(spacing: Spacing.s) {
                    ForEach(localPlaylists) { playlist in
                        LocalPlaylistRow(playlist: playlist) {
                            selectedPlaylist = playlist.playlist
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ColorTokens.surface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
            } else {
                Text("No playlists yet.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, Spacing.l)
            }
        }
    }

    private var divider: some View {
        HStack {
            Rectangle()
                .fill(ColorTokens.hairline)
                .frame(height: 1)
            Spacer()
        }
        .padding(.vertical, Spacing.s)
    }

    // MARK: actions

    private func refreshSmartTiles() {
        guard let service = libraryService else { return }
        smartTiles = [
            .favorites(songCount: service.favoriteSongs().count),
            .mostPlayed(songCount: service.mostPlayedSongs().count),
            .recentlyPlayed(songCount: service.recentlyPlayedSongs().count),
        ]
    }

    private func tapSmartTile(_ tile: SmartPlaylistTileModel) {
        guard let service = libraryService else { return }
        let songs: [Song]
        switch tile.kind {
        case .favorites:
            songs = service.favoriteSongs()
        case .mostPlayed:
            songs = service.mostPlayedSongs()
        case .recentlyPlayed:
            songs = service.recentlyPlayedSongs()
        }
        guard !songs.isEmpty else { return }
        let (requests, startIndex) = service.playbackRequests(
            for: songs,
            startingAt: nil
        )
        audioEngine.playQueue(requests, startIndex: startIndex)
        presentingNowPlaying = true
    }

    private func createPlaylist() {
        let trimmed = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let service = LibraryService(context: modelContext)
        _ = service.createPlaylist(title: trimmed)
        newPlaylistName = ""
    }
}

// MARK: - Models

struct SmartPlaylistTileModel: Identifiable {
    let id: UUID
    let kind: SmartPlaylistTile.Kind
    let songCount: Int

    init(kind: SmartPlaylistTile.Kind, songCount: Int) {
        self.id = UUID()
        self.kind = kind
        self.songCount = songCount
    }

    static func favorites(songCount: Int) -> Self {
        Self(kind: .favorites, songCount: songCount)
    }
    static func mostPlayed(songCount: Int) -> Self {
        Self(kind: .mostPlayed, songCount: songCount)
    }
    static func recentlyPlayed(songCount: Int) -> Self {
        Self(kind: .recentlyPlayed, songCount: songCount)
    }
}

extension SmartPlaylistTile.Kind {
    var emptyLabel: String {
        switch self {
        case .favorites:   "No favorites yet"
        case .mostPlayed:  "No most-played tracks yet"
        case .recentlyPlayed: "No recently played tracks yet"
        }
    }
}

struct LocalPlaylistModel: Identifiable {
    let id = UUID()
    let playlist: Playlist

    static var sample: Self {
        let pl = Playlist(title: "Sample Playlist")
        return Self(playlist: pl)
    }
}

private extension SmartPlaylistTile.Kind {
    func play(requests: [PlaybackRequest], startIndex: Int) {
        // Placeholder for future expansion; playback is triggered via
        // PlaylistView.tapSmartTile for now.
    }
}

// MARK: - Smart tile button

private struct SmartTileButton: View {
    let tile: SmartPlaylistTileModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                tile.kind.icon
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)

                Text(tile.kind.title)
                    .font(Typography.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if tile.songCount > 0 {
                    Text("\(tile.songCount)")
                        .font(Typography.caption1)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.s)
            .background(tile.kind.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
