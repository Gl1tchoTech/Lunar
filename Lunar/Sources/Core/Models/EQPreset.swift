import Foundation
import SwiftData

/// One EQ preset, either user-saved or built-in.
///
/// `bands` is a **native** `[Float]` — SwiftData encodes/transcodes
/// primitive arrays for us, no manual JSON step required.
@Model
final class EQPreset {

    var id: UUID
    var name: String

    /// `true` = factory preset (cannot be deleted by the user).
    var isBuiltIn: Bool

    /// 10 band gains in dB. Range: -12 ... +12. Bands correspond to
    /// the standard ISO frequencies: 32, 64, 128, 256, 512, 1k, 2k,
    /// 4k, 8k, 16k Hz.
    var bands: [Float]

    var dateCreated: Date

    init(
        id: UUID = UUID(),
        name: String,
        isBuiltIn: Bool = false,
        bands: [Float],
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.bands = bands
        self.dateCreated = dateCreated
    }
}
