import SwiftUI
import SwiftData

/// The user's choice of sort field. Drives `LibraryView`'s `@Query`.
enum LibrarySortKey: String, CaseIterable, Identifiable {
    case songName
    case artistName
    case recentlyAdded
    case latestPlayed
    case size
    case mostPlayed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .songName:       "Song name"
        case .artistName:     "Artist name"
        case .recentlyAdded:  "Recently added"
        case .latestPlayed:   "Latest played"
        case .size:           "Size"
        case .mostPlayed:     "Most Played"
        }
    }
}

enum SortDirection: String, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascending:  "Ascending"
        case .descending: "Descending"
        }
    }

    var systemImage: String {
        switch self {
        case .ascending:  "arrow.up"
        case .descending: "arrow.down"
        }
    }
}

/// Modal sheet triggered from the library `↑↓` chip. Two grouped
/// sections (Sort by + Direction) plus checkmark indicators.
struct SortMenu: View {

    @Binding var sortKey: LibrarySortKey
    @Binding var direction: SortDirection
    let totalSongs: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                // Group 1 — Sort by
                ForEach(LibrarySortKey.allCases) { key in
                    sortRow(key: key)
                }
                Divider().background(ColorTokens.hairline)
                // Group 2 — Direction
                ForEach(SortDirection.allCases) { dir in
                    directionRow(dir: dir)
                }
            }
            .padding(.vertical, Spacing.s)

            Spacer(minLength: 0)
        }
        .background(ColorTokens.canvas.ignoresSafeArea())
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Spacer()
            Text("Sort").font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
        }
        .padding(.top, Spacing.l)
    }

    private func sortRow(key: LibrarySortKey) -> some View {
        Button {
            sortKey = key
        } label: {
            HStack {
                Text(key.label)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                if sortKey == key {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ColorTokens.appAccent)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func directionRow(dir: SortDirection) -> some View {
        Button {
            direction = dir
        } label: {
            HStack {
                Image(systemName: dir.systemImage)
                    .foregroundStyle(ColorTokens.appAccent)
                Text(dir.label)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                if direction == dir {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ColorTokens.appAccent)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
