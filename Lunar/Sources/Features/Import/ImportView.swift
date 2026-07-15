import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import tab — main surface for bringing local audio into the library.
///
/// **Tier 6 update.** Before this rewrite, `isImporting`, `lastImportIDs`,
/// and `importError` lived as `@State` on this view. That meant URLs
/// delivered by iOS's **"Open In..."** UI (Other Apps handoff) were
/// silently dropped whenever the user wasn't sitting on the Import tab.
/// Those three properties now live on `ImportManager` (an `@Observable`
/// owned by `LunarApp` and injected into the environment via
/// `.environment(importManager)`). The view is now a pure presentation
/// layer that:
///
/// 1. Opens the system `.fileImporter` for *manual* file picks.
/// 2. Forwards picker results to `importManager.enqueueMany`.
/// 3. Reads `importManager.isImporting` / `lastImportIDs` / `importError`
///    for display.
///
/// The `onOpenURL` scene-level handler in `LunarAppCoordinator` is the
/// *other* entry point — it lands plain URLs straight into the same
/// `importManager.enqueue(_:)` queue.
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
/// installed. `CFBundleDocumentTypes` in `project.yml` also registers
/// Lunar as an alternate "Open In..." target so external apps (Files,
/// VLC, Shortcuts) can hand URLs over via `.onOpenURL`.
///
/// **Now Playing binding** — held locally as `@State` so the same
/// flag flip drives both the `.safeAreaInset` `MiniPlayer` (which
/// writes `true`) **and** the `.fullScreenCover` that opens
/// `NowPlayingView`.
@MainActor
struct ImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(ImportManager.self) private var importManager

    @Query(sort: [SortDescriptor(\Song.dateAdded, order: .reverse)])
    private var allSongs: [Song]

    /// Local because only this view flips it; the binding is shared
    /// between the toolbar `+` button, the hero CTA, and the
    /// `fileImporter` modifier.
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
                presenting: importManager.importError
            ) { _ in
                Button("OK", role: .cancel) { importManager.clearError() }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Layouts

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
        // Tier 6 — read `lastImportIDs` off the manager so a batch
        // imported via "Open In..." on a different tab also shows up
        // here when the user navigates back to Import.
        let recent = allSongs.filter { song in
            importManager.lastImportIDs.contains(song.persistentModelID)
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
                // Tier 6 — spinner now reads from the manager so it
                // also rotates while a batch imported via .onOpenURL
                // is in flight.
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

    // MARK: - Actions

    private func openPicker() {
        guard !importManager.isImporting else { return }
        isPickerPresented = true
    }

    private func handlePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            // Tier 6 — no local `runImport`. Forward straight to the
            // manager; the same drain path also handles `.onOpenURL`.
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

    /// Drives the post-batch alert. Becomes `true` while the
    /// manager's `importError` is non-nil; presenter clears it
    /// back to `nil` on dismissal.
    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importManager.importError != nil },
            set: { newValue in if !newValue { importManager.clearError() } }
        )
    }
}

// MARK: - ImportSongRow

/// Single row in the Import tab's lists. Mirrors `SongRow` shape but
/// does not depend on `LibraryService.onToggleFavorite` since the
/// Import tab is read-only for now (favorites are toggled from Library).
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
        .environment(ImportManager())
        .preferredColorScheme(.dark)
}
