import SwiftUI
import SwiftData

/// Song metadata editor presented from the Library context menu.
@MainActor
struct SongInfoSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let song: Song

    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var album: String = ""
    @State private var trackNumber: String = ""
    @State private var year: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        artworkSection
                        formSection
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Song Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorTokens.appAccent)
                }
            }
        }
        .onAppear {
            title = song.title
            artist = song.artist
            album = song.albumTitle ?? ""
            trackNumber = song.trackNumber.map(String.init) ?? ""
            year = song.year.map(String.init) ?? ""
        }
    }

    private var artworkSection: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.s) {
                if let data = song.artwork, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ColorTokens.elevated)
                        .frame(width: 160, height: 160)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(ColorTokens.textTertiary)
                        )
                }

                Text(song.title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(formatDuration(song.duration))
                    .font(Typography.subhead)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(.vertical, Spacing.m)
    }

    private var formSection: some View {
        VStack(spacing: Spacing.m) {
            formField(title: "Title", text: $title)
            formField(title: "Artist", text: $artist)
            formField(title: "Album", text: $album)
            HStack(spacing: Spacing.m) {
                formField(title: "Track", text: $trackNumber, keyboardType: .numberPad)
                formField(title: "Year", text: $year, keyboardType: .numberPad)
            }
        }
        .modifier(ColorTokens.glassCard(cornerRadius: 18))
    }

    private func formField(title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.caption1)
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, Spacing.m)
            TextField(title, text: text)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                #if !os(macOS)
                .keyboardType(keyboardType)
                #endif
        }
    }

    private func save() {
        song.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        song.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        song.albumTitle = album.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        song.trackNumber = Int(trackNumber.trimmingCharacters(in: .whitespacesAndNewlines))
        song.year = Int(year.trimmingCharacters(in: .whitespacesAndNewlines))

        try? modelContext.save()
        dismiss()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
