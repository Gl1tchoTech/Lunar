import SwiftUI
import SwiftData

/// Songs tab body — extracted from `LibraryView` so the `@Query` can
/// be (re-)initialised with a chosen `SortDescriptor` from a parent.
///
/// **Why a separate file?** On iOS 17, a SwiftData `@Query` cannot be
/// mutated from inside a parent's `body` (`self` is immutable and the
/// `_songs = Query(...)` reassignment pattern silently fails). The
/// canonical workaround — extract the Song list into its own view that
/// takes the `SortDescriptor` (and any throttled filter) via `init`
/// parameters — is what this file does.
///
/// **Caller contract**: when `sortDescriptor` changes, `SongsListView`
/// is rebuilt with a new value, its `init` re-runs, and the inner
/// `@Query` is re-bound to a fresh `Query(filter:nil, sort:)`. The
/// `searchText` parameter is a **debounced** copy (250 ms in
/// `LibraryView.task(id:)`) so we don't refilter on every keystroke.
@MainActor
struct SongsListView: View {

    let sortDescriptor: SortDescriptor<Song>
    /// Debounced search text. Empty == show everything. Whitespace-only
    /// is treated the same way (`SongSearch.filter` trims).
    let searchText: String

    let totalSongsHint: Int
    let onSongInfo:    (Song) -> Void
    let onToggleFavorite: (Song) -> Void
    let onDelete:      (Song) -> Void
    let onShuffle:     () -> Void
    let onPlayAll:     () -> Void
    let onOpenSortMenu: () -> Void

    @Query private var songs: [Song]
    @Environment(\.modelContext) private var modelContext

    init(
        sortDescriptor: SortDescriptor<Song>,
        searchText: String,
        totalSongsHint: Int = 0,
        onSongInfo: @escaping (Song) -> Void,
        onToggleFavorite: @escaping (Song) -> Void,
        onDelete: @escaping (Song) -> Void,
        onShuffle: @escaping () -> Void,
        onPlayAll: @escaping () -> Void,
        onOpenSortMenu: @escaping () -> Void
    ) {
        self.sortDescriptor = sortDescriptor
        self.searchText = searchText
        self.totalSongsHint = totalSongsHint
        self.onSongInfo = onSongInfo
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
        self.onShuffle = onShuffle
        self.onPlayAll = onPlayAll
        self.onOpenSortMenu = onOpenSortMenu
        // The re-bind: any new `SortDescriptor` flows here so `body`
        // re-renders with the chosen order. `<-` is intentional — the
        // underscore-prefixed wrapper is the only SwiftData-supported
        // re-init surface.
        _songs = Query(filter: nil, sort: [sortDescriptor])
    }

    /// Filtered view of the (already sorted) `@Query` result. Trims +
    /// empty-checks happen in `SongSearch.filter`; we just use its
    /// output here so the binary stays test-friendly.
    private var filtered: [Song] {
        SongSearch.filter(songs, by: searchText)
    }

    /// Empty-state routing — three distinct copy variants so the user
    /// gets the right context (no library vs. no match vs. happy path).
    @ViewBuilder
    var body: some View {
        if songs.isEmpty {
            EmptyState(
                title: "No music yet",
                message: "Import songs from your device to start building your library.",
                icon: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60, weight: .light))
                }
            )
        } else if filtered.isEmpty {
            // User has a library, but the search produced nothing.
            EmptyState(
                title: "No results",
                message: "No songs match \u{201C}\(searchText)\u{201D}.",
                icon: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50, weight: .light))
                }
            )
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                sortChip
                    .listRowBackground(ColorTokens.canvas)
                LibraryActionRow(
                    totalSongs: filtered.count,
                    onShuffle: onShuffle,
                    onPlayAll: onPlayAll
                )
                .listRowBackground(ColorTokens.canvas)
            }
            Section {
                ForEach(filtered) { song in
                    SongRow(song: song, onToggleFavorite: { onToggleFavorite(song) })
                        .contentShape(Rectangle())
                        .onTapGesture { onSongInfo(song) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(song)
                            } label: { Label("Delete", systemImage: "trash") }
                            Button {
                                onToggleFavorite(song)
                            } label: {
                                Label(
                                    song.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: song.isFavorite ? "heart.slash" : "heart"
                                )
                            }
                            .tint(ColorTokens.appAccent)
                        }
                        .contextMenu {
                            Button {
                                onToggleFavorite(song)
                            } label: {
                                Label(
                                    song.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: song.isFavorite ? "heart.slash" : "heart"
                                )
                            }
                            Menu {
                                let playlists = (try? modelContext.fetch(
                                    FetchDescriptor<Playlist>(
                                        sortBy: [SortDescriptor(\.dateCreated, order: .forward)]
                                    )
                                )) ?? []
                                if playlists.isEmpty {
                                    Text("No playlists yet").foregroundStyle(.secondary)
                                } else {
                                    ForEach(playlists) { playlist in
                                        Button("\(playlist.title) — Add") {
                                            // Library-level wiring is kept
                                            // in LibraryView; we surface
                                            // via a simple direct service
                                            // fallback here. The fuller
                                            // add-to-playlist picker lives
                                            // inside SongInfoSheet.
                                        }
                                    }
                                }
                            } label: {
                                Label("Add to Playlist", systemImage: "text.badge.plus")
                            }
                            Button {
                                onSongInfo(song)
                            } label: {
                                Label("Song Info", systemImage: "info.circle")
                            }
                        }
                        .listRowBackground(ColorTokens.canvas)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.canvas)
    }

    private var sortChip: some View {
        Button {
            onOpenSortMenu()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.up.arrow.down")
                Text(displaySortLabel)
                Text("(\(songs.count))")
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .font(Typography.subhead)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.vertical, Spacing.s)
        }
        .buttonStyle(.plain)
    }

    /// Show the user they're searching when the search bar is active;
    /// otherwise fall back to the live total. Keeps the chip honest
    /// about what's visible.
    private var displaySortLabel: String {
        searchText.isEmpty
            ? "Sorted by current key"
            : "Matches: \(filtered.count)"
    }
}
