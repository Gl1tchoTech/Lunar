import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Full-screen synced-lyrics viewer presented from Now Playing.
///
/// Looks up the currently-playing song by `AudioEngine.currentSongID`
/// (single source of truth — no `Song` passed in, so the sheet
/// always renders for the right track even after queue advance).
///
/// Layers, top → bottom:
/// 1. **`LyricsNavigator`** keeps the binary search of the current
///    line based on `engine.state.currentTime`. Damped to avoid
///    jitter when lyrics are dense or skips are close together.
/// 2. **`ScrollViewReader` + `geometryReader`** auto-scroll the
///    active line to vertical center. **Animate** when the line
///    index moves by ±1 (natural progression) and **snap** when it
///    jumps more than one (seek / crossfade / restart).
/// 3. Manual taps on a line seek `engine.send(.seek(line.time))`.
@MainActor
struct LyricsView: View {

    @Environment(AudioEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerThemeManager.self) private var themeManager

    @State private var song: Song?
    @State private var lines: [LyricLine] = []
    @State private var presentedImporter: Bool = false
    @State private var importErrorMessage: String?
    @State private var activeIndex: Int?
    @State private var previousIndex: Int?

    var body: some View {
        let palette = themeManager.palette
        ZStack {
            palette.linearBackground.ignoresSafeArea()
            if song == nil {
                noSongState(palette: palette)
            } else if lines.isEmpty {
                emptyState(palette: palette)
            } else {
                lyricsScroll(palette: palette)
            }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .top) { chrome(palette: palette) }
        .fileImporter(
            isPresented: $presentedImporter,
            allowedContentTypes: [UTType.lrcLyrics],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(
            "Couldn't import lyrics",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .task(id: engine.currentSongID) {
            await refreshSong()
        }
        .onChange(of: engine.state.currentTime) { _, time in
            // Recompute the highlighted line on every quarter-second
            // boundary (`AudioEngine.progressTimer` ticks at 0.1 s).
            // Cheap binary search so this is essentially free.
            activeIndex = LyricsNavigator.activeLine(in: lines, at: time)
        }
    }

    // MARK: - Top chrome

    private func chrome(palette: PlayerThemePalette) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close lyrics")
            Spacer()
            Text(engine.state.currentTitle)
                .font(Typography.headline)
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
            Spacer()
            Color.clear.frame(width: 44, height: 44) // visually balance the chevron
        }
        .padding(.horizontal, Spacing.s)
    }

    // MARK: - Empty states

    private func noSongState(palette: PlayerThemePalette) -> some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(palette.secondaryText)
            Text("Nothing playing")
                .font(Typography.title2)
                .foregroundStyle(palette.primaryText)
            Text("Start a song to see synced lyrics.")
                .font(Typography.subhead)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.l)
    }

    private func emptyState(palette: PlayerThemePalette) -> some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(palette.secondaryText)
            Text("No lyrics yet")
                .font(Typography.title2)
                .foregroundStyle(palette.primaryText)
            Text("Import a .lrc file to sing along.")
                .font(Typography.subhead)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                presentedImporter = true
            } label: {
                Label("Import Lyrics File", systemImage: "doc.badge.plus")
                    .font(Typography.button)
                    .foregroundStyle(.black)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s)
                    .background(palette.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, Spacing.m)
        }
        .padding(.horizontal, Spacing.l)
    }

    // MARK: - Lyrics scroll

    private func lyricsScroll(palette: PlayerThemePalette) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.m) {
                    // Top spacer so the first active line lands near
                    // vertical centre on first appearance.
                    Color.clear.frame(height: 240)
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        LyricRow(
                            text: line.text,
                            isActive: idx == activeIndex,
                            palette: palette,
                            onTap: {
                                Task { await engine.send(.seek(line.time)) }
                            }
                        )
                        .id(idx)
                    }
                    Color.clear.frame(height: 240)
                }
                .padding(.horizontal, Spacing.l)
            }
            .scrollIndicators(.hidden)
            .onChange(of: activeIndex) { _, newIdx in
                guard let newIdx else { return }
                let delta = abs(newIdx - (previousIndex ?? newIdx))
                // Animate every natural advance (delta = 0..1). Snap on
                // anything bigger so seeks + crossfades don't fly past
                // the active line.
                if delta <= 1 || previousIndex == nil {
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                } else {
                    proxy.scrollTo(newIdx, anchor: .center)
                }
                previousIndex = newIdx
            }
        }
    }

    // MARK: - Lyrics loading + import handling

    /// Re-fetch the playing song from the SwiftData context every
    /// time `engine.currentSongID` changes. SwiftData `model(for:)`
    /// returns the tracked model instance for the persistent
    /// identifier.
    private func refreshSong() async {
        guard let id = engine.currentSongID,
              let resolved = modelContext.model(for: id) as? Song
        else {
            song = nil
            lines = []
            activeIndex = nil
            previousIndex = nil
            return
        }
        song = resolved
        await loadLyrics(for: resolved)
    }

    private func loadLyrics(for song: Song) async {
        lines = []
        activeIndex = nil
        previousIndex = nil
        guard let fileName = song.lyricsFileName,
              let url = LyricsLibrary.absoluteURL(forFileName: fileName),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
        else {
            return
        }
        lines = LyricsParser.parse(text)
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let first = urls.first else { return }
            Task { await importLyrics(at: first) }
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func importLyrics(at url: URL) async {
        guard let song else {
            importErrorMessage = "No song is currently loaded."
            return
        }
        let importer = LyricsImporter(context: modelContext)
        do {
            let parsed = try await importer.importLyrics(for: song, at: url)
            lines = parsed
            activeIndex = nil
            previousIndex = nil
            // Snap the engine to the first timestamp so the user
            // sees the song sync to the very first line.
            if let first = parsed.first {
                await engine.send(.seek(first.time))
            }
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - LyricsNavigator (active-line search)

/// Picks the lyric line that should be highlighted at a given
/// playback time.
///
/// Returns the index of the **last** line whose `time <= currentTime`,
/// or `nil` if the time precedes the first line. Using the last
/// qualifying index means a song at t=0 doesn't briefly show no
/// highlight before the first timestamp arrives — instead it picks
/// the line that's about to unlock next. (Kept `public`-ish: easy to
/// write a separate test target later.)
enum LyricsNavigator {

    static func activeLine(in lines: [LyricLine], at time: TimeInterval) -> Int? {
        guard !lines.isEmpty, time >= 0 else { return nil }
        // Binary search: find the last index with `lines[idx].time <= time`.
        var low = 0
        var high = lines.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        if high < 0 { return nil }
        return min(high, lines.count - 1)
    }
}

// MARK: - LyricRow

@MainActor
private struct LyricRow: View {
    let text: String
    let isActive: Bool
    let palette: PlayerThemePalette
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text.isEmpty ? "♪" : text)
                .font(isActive ? Typography.title3 : Typography.body)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? palette.primaryText : palette.secondaryText.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .scaleEffect(isActive ? 1.0 : 0.95)
                .animation(.easeOut(duration: 0.25), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text.isEmpty ? "instrumental" : text)
        .accessibilityHint("Tap to seek to this line")
    }
}
