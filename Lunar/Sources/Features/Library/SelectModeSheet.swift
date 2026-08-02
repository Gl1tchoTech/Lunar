import SwiftUI
import SwiftData

/// Multi-select mode sheet for the Library.
///
/// Presents a checklist of songs with bulk actions: Play, Add to Playlist,
/// Favorite, and Delete. Tapping a row toggles its selection.
@MainActor
struct SelectModeSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(\.dismiss) private var dismiss

    let songs: [Song]

    @State private var selectedIDs: Set<UUID> = []
    @State private var showingAddToPlaylist = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        statusHeader
                        ForEach(songs) { song in
                            SelectRow(
                                song: song,
                                isSelected: selectedIDs.contains(song.id)
                            ) {
                                toggle(song)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if allSelected {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(songs.map(\.id))
                        }
                    } label: {
                        Text(allSelected ? "Deselect All" : "Select All")
                            .foregroundStyle(ColorTokens.appAccent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomActionBar }
        }
        .confirmationDialog(
            "Add to Playlist",
            isPresented: $showingAddToPlaylist,
            titleVisibility: .visible
        ) {
            Button("Create New Playlist") {
                createPlaylistFromSelection()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose where to add the selected songs.")
        }
        .alert("Delete Songs?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelected()
            }
        } message: {
            Text("This will remove \(selectedIDs.count) song\(selectedIDs.count == 1 ? "" : "s") from your library.")
        }
    }

    private var allSelected: Bool {
        !songs.isEmpty && selectedIDs.count == songs.count
    }

    private var statusHeader: some View {
        HStack {
            Text("\(selectedIDs.count) selected")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    private func toggle(_ song: Song) {
        if selectedIDs.contains(song.id) {
            selectedIDs.remove(song.id)
        } else {
            selectedIDs.insert(song.id)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: Spacing.m) {
            actionButton(systemImage: "play.fill", label: "Play", isPrimary: true) {
                playSelected()
            }
            actionButton(systemImage: "plus", label: "Playlist") {
                showingAddToPlaylist = true
            }
            actionButton(systemImage: "heart", label: "Favorite") {
                favoriteSelected()
            }
            actionButton(systemImage: "trash", label: "Delete", isDestructive: true) {
                showingDeleteConfirm = true
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(
            ColorTokens.canvas
                .ignoresSafeArea()
                .opacity(0.95)
        )
    }

    private func actionButton(
        systemImage: String,
        label: String,
        isPrimary: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(Typography.caption1)
            }
            .foregroundStyle(
                isPrimary ? .black :
                isDestructive ? ColorTokens.destructive : ColorTokens.textPrimary
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isPrimary ? ColorTokens.appAccent :
                        isDestructive ? ColorTokens.destructive.opacity(0.15) :
                        ColorTokens.surface
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedIDs.isEmpty)
    }

    private func selectedSongs() -> [Song] {
        songs.filter { selectedIDs.contains($0.id) }
    }

    private func playSelected() {
        let selected = selectedSongs()
        guard !selected.isEmpty else { return }
        let service = LibraryService(context: modelContext)
        let requests = service.playbackRequests(for: selected)
        audioEngine.playQueue(requests)
        dismiss()
    }

    private func favoriteSelected() {
        let service = LibraryService(context: modelContext)
        selectedSongs().forEach { service.toggleFavorite($0) }
        dismiss()
    }

    private func deleteSelected() {
        let service = LibraryService(context: modelContext)
        selectedSongs().forEach { service.delete($0) }
        dismiss()
    }

    private func createPlaylistFromSelection() {
        let service = LibraryService(context: modelContext)
        let playlist = service.createPlaylist(title: "Selected Songs")
        let selected = selectedSongs()
        selected.forEach { service.add($0, to: playlist) }
        dismiss()
    }
}

// MARK: - Select Row

@MainActor
private struct SelectRow: View {
    let song: Song
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? ColorTokens.appAccent : ColorTokens.elevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .black : ColorTokens.textTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(Typography.subhead)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .modifier(ColorTokens.glassCard(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
