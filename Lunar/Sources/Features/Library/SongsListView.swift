import SwiftUI
import SwiftData

/// Songs tab body with MeloPlayer-style rounded rows and action pills.
@MainActor
struct SongsListView: View {

    let sortDescriptor: SortDescriptor<Song>
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
        _songs = Query(filter: nil, sort: [sortDescriptor])
    }

    private var filtered: [Song] {
        SongSearch.filter(songs, by: searchText)
    }

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
        ScrollView {
            VStack(spacing: Spacing.m) {
                actionPills
                ForEach(filtered) { song in
                    SongRow(song: song, onToggleFavorite: { onToggleFavorite(song) })
                        .contentShape(Rectangle())
                        .onTapGesture { onSongInfo(song) }
                        .contextMenu {
                            contextMenu(for: song)
                        }
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, 140) // room for floating mini-player + tab bar
        }
    }

    private var actionPills: some View {
        HStack(spacing: Spacing.s) {
            sortChip
            Spacer()
            pillButton(systemImage: "shuffle", label: "Shuffle", action: onShuffle)
            pillButton(systemImage: "play.fill", label: "Play All", action: onPlayAll)
        }
    }

    private var sortChip: some View {
        Button {
            onOpenSortMenu()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                Text("Sort")
                    .font(Typography.subhead)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func pillButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(Typography.subhead)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTokens.appAccent)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextMenu(for song: Song) -> some View {
        Button {
            onToggleFavorite(song)
        } label: {
            Label(
                song.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: song.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button {
            onSongInfo(song)
        } label: {
            Label("Song Info", systemImage: "info.circle")
        }
        Button(role: .destructive) {
            onDelete(song)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
