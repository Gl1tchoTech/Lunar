import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import tab with MeloPlayer liquid-glass styling.
@MainActor
struct ImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(ImportManager.self) private var importManager

    @Query(sort: [SortDescriptor(\.Song.dateAdded, order: .reverse)])
    private var allSongs: [Song]

    @State private var isPickerPresented = false
    @State private var presentingNowPlaying = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                if allSongs.isEmpty {
                    emptyStatePlaceholder
                } else {
                    libraryContent
                }
            }
            .background(ColorTokens.canvas)
            .navigationTitle("Import")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handlePicker(result: result)
            }
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
            .alert(
                "Some files couldn't be imported",
                isPresented: importErrorBinding,
                presenting: importManager.importError
            ) { _ in
                Button("OK", role: .cancel) { importManager.clearError() }
            } message: { message in
                Text(message)
            }
        }
    }

    private var emptyStatePlaceholder: some View {
        EmptyState(
            title: "No music yet",
            message: "Bring in audio from Files, iCloud Drive, On My iPhone, or other apps. Lunar reads ID3 / iTunes / Vorbis tags and embedded artwork automatically.",
            primaryActionTitle: "Import Audio Files",
            primaryAction: openPicker,
            icon: {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 60, weight: .light))
            }
        )
    }

    @ViewBuilder
    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header
                heroCard
                importedTodaySection
                allLibrarySection
                Spacer(minLength: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.pageHorizontalInset)
            .padding(.top, Spacing.m)
            .padding(.bottom, 140)
        }
    }

    private var header: some View {
        HStack {
            Text("Import")
                .font(Typography.display)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
    }

    private var heroCard: some View {
        Button(action: openPicker) {
            HStack(spacing: Spacing.m) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ColorTokens.appAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Audio Files")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("From Files, iCloud Drive, On My iPhone, or other apps")
                        .font(Typography.caption1)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity)
            .modifier(ColorTokens.glassCard(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTokens.appAccent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var importedTodaySection: some View {
        let recent = allSongs.filter { song in
            importManager.lastImportIDs.contains(song.persistentModelID)
        }
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                sectionHeader(
                    title: "Imported Today",
                    subtitle: "\(recent.count) \(recent.count == 1 ? "song" : "songs")"
                )
                VStack(spacing: Spacing.m) {
                    ForEach(recent) { song in
                        ImportSongRow(song: song, tapHandler: { play(song) })
                    }
                }
            }
        }
    }

    private var allLibrarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader(
                title: "All Library",
                subtitle: "\(allSongs.count) \(allSongs.count == 1 ? "song" : "songs")"
            )
            VStack(spacing: Spacing.m) {
                ForEach(allSongs.prefix(20)) { song in
                    ImportSongRow(song: song, tapHandler: { play(song) })
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Text(subtitle)
                .font(Typography.caption1)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, Spacing.xs)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                openPicker()
            } label: {
                if importManager.isImporting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "plus")
                }
            }
            .disabled(importManager.isImporting)
        }
    }

    private func openPicker() {
        guard !importManager.isImporting else { return }
        isPickerPresented = true
    }

    private func handlePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            importManager.enqueueMany(urls)
        case .failure(let error):
            importManager.importError = error.localizedDescription
        }
    }

    private func play(_ song: Song) {
        let service = LibraryService(context: modelContext)
        let (requests, startIndex) = service.playbackRequests(
            for: allSongs,
            startingAt: song.persistentModelID
        )
        guard !requests.isEmpty else { return }
        Task { await audioEngine.playQueue(requests, startIndex: startIndex) }
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importManager.importError != nil },
            set: { newValue in if !newValue { importManager.clearError() } }
        )
    }
}

// MARK: - ImportSongRow

@MainActor
private struct ImportSongRow: View {
    let song: Song
    let tapHandler: () -> Void

    var body: some View {
        Button(action: tapHandler) {
            HStack(spacing: Spacing.m) {
                songArtwork(size: Spacing.albumArtSmall)
                    .frame(width: Spacing.albumArtSmall, height: Spacing.albumArtSmall)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(Typography.caption1)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(formatDuration(song.duration))
                    .font(Typography.caption1)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .modifier(ColorTokens.glassCard(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func songArtwork(size: CGFloat) -> some View {
        if let data = song.artwork, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ColorTokens.elevated)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(ColorTokens.textTertiary)
                )
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
