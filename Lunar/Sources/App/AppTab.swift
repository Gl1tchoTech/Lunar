import Foundation

/// All top-level destinations in Lunar's tab bar / sidebar.
enum AppTab: String, Hashable, Identifiable, CaseIterable, Codable {
    case library
    case playlist
    case importer
    case browse
    case settings

    var id: Self { self }

    /// Title shown in the tab bar / sidebar list / portrait titles.
    var title: String {
        switch self {
        case .library:   "Library"
        case .playlist:  "Playlist"
        case .importer:  "Import"
        case .browse:    "Browse"
        case .settings:  "Settings"
        }
    }

    /// SF Symbol used for the tab bar / sidebar list row.
    var systemImage: String {
        switch self {
        case .library:   "music.note.list"
        case .playlist:  "music.note.tv"
        case .importer:  "square.and.arrow.down"
        case .browse:    "magnifyingglass"
        case .settings:  "gearshape"
        }
    }
}
