import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import tab — main surface for bringing local audio into the library.
///
/// **Surface layout (top → bottom):**
/// 1. Header — `Import` title with a `+` toolbar button.
/// 2. Hero CTA → opens the system document picker via SwiftUI's
///    `.fileImporter` (`.audio` content type).
/// 3. `Imported Today` — songs added in the most recent import batch.
/// 4. `All Library` — every imported song sorted by `dateAdded` desc.
///
/// **Picker scope** — `UTType.audio` shows Local Files, iCloud Drive,
/// `On My iPhone`, and any third-party Files providers the user has
/// installed.
///
/// **State machine:**
/// - `isPickerPresented`  — driven by the toolbar `+` and the hero CTA.
/// - `isImporting`        — drives the toolbar spinner; also disables
///    re-opening the picker while a batch is mid-flight.
/// - `lastImportIDs`      — `PersistentIdentifier`s added in the most
///    recent batch; filters the `Imported Today` section.
/// - `importError`        — surfaces `failed` URLs after a partial
///    success, or copy/extraction errors.
///
/// **Now Playing binding** — held locally as `@State` so the same
/// flag flip drives both the `.safeAreaInset` `MiniPlayer` (which
/// writes `true`) **and** the `.fullScreenCover` that opens
/// `NowPlayingView`.
struct ImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine

    @Query(sort: [SortDescriptor(\Song.dateAdded, order: .reverse)])
    private var allSongs: [Song]

    @State private var isPickerPresented = false
    @State private var isImporting = false
    @State private var presentingNowPlaying = false
    @State private var lastImportIDs: [PersistentIdentifier] = []
    @State private var importError: String?

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
            .safeAreaInset(edge: .bottom) {
                MiniPlayer(isPresented: $presentingNowPlaying)
            }
            .fullScreenCover(isPresented: $presentingNowPlaying) {
                NowPlayingView()
                    .environment(audioEngine)
            }
            .alert(
                "Some files couldn't be imported",
                isPresented: importErrorBinding,
                presenting: importError
            ) { _ in
                Button("OK", role: .cancel) { importError = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Layouts

    private var emptyStatePlaceholder: some View {
        EmptyState(
            title: "No music yet",
            message: "Bring in audio from Files, iCloud Drive, or other apps. Lunar reads ID3 / iTunes / Vorbis tags and embedded artwork automatically.",
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
            VStack(spacing: Spacing.l) {
                heroCard
                importedTodaySection
                allLibrarySection
                Spacer(minLength: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.pageHorizontalInset)
            .padding(.top, Spacing.m)
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
                    Text("From Files, iCloud Drive, or other apps")
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
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous)
                    .stroke(ColorTokens.appAccent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var importedTodaySection: some View {
        let recent = allSongs.filter { song in
            lastImportIDs.contains(song.persistentModelID)
        }
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                sectionHeader(
                    title: "Imported Today",
                    subtitle: "\(recent.count) \(recent.count == 1 ? "song" : "songs")"
                )
                VStack(spacing: 0) {
                    ForEach(recent) { song in
                        ImportSongRow(song: song, tapHandler: { play(song) })
                        if song.persistentModelID != recent.last?.persistentModelID {
                            Divider().background(ColorTokens.hairline)
                        }
                    }
                }
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
            }
        }
    }

    private var allLibrarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader(
                title: "All Library",
                subtitle: "\(allSongs.count) \(allSongs.count == 1 ? "song" : "songs")"
            )
            VStack(spacing: 0) {
                ForEach(allSongs.prefix(20)) { song in
                    ImportSongRow(song: song, tapHandler: { play(song) })
                    if song.persistentModelID != allSongs.prefix(20).last?.persistentModelID {
                        Divider().background(ColorTokens.hairline)
                    }
                }
            }
            .background(ColorTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.title3)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Text(subtitle)
                .font(Typography.caption1)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                openPicker()
            } label: {
                if isImporting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "plus")
                }
            }
            .disabled(isImporting)
        }
    }

    // MARK: - Actions

    private func openPicker() {
        guard !isImporting else { return }
        isPickerPresented = true
    }

    private func handlePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task { await runImport(urls: urls) }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func runImport(urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        let importer = MusicImporter(context: modelContext)
        do {
            let result = try await importer.importFiles(at: urls)
            lastImportIDs = result.inserted

            if !result.failed.isEmpty {
                let names = result.failed.prefix(3)
                    .map { ($0.url as NSURL).lastPathComponent ?? "?" }
                    .joined(separator: ", ")
                importError = "\(result.failed.count) file\(result.failed.count == 1 ? "" : "s") failed: \(names)"
            }
        } catch {
            importError = error.localizedDescription
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

    /// Drives the post-batch alert. Becomes `true` while `importError`
    /// is non-nil; presenter clears it back to `nil` on dismissal.
    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { newValue in if !newValue { importError = nil } }
        )
    }
}

// MARK: - ImportSongRow

/// Single row in the Import tab's lists. Mirrors `SongRow` shape but
/// does not depend on `LibraryService.onToggleFavorite` since the
/// Import tab is read-only for now (favorites are toggled from Library).
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
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ColorTokens.elevated)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(ColorTokens.textTertiary)
                )
        }
    }

    /// `m:ss` formatter (no leading hour — most pop/electronic tracks
    /// never hit an hour). Mirrors the Library row formatter so the
    /// two surfaces stay visually consistent.
    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ImportView()
        .environment(AudioEngine())
        .preferredColorScheme(.dark)
}
