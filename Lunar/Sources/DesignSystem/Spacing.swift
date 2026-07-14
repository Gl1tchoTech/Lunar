import SwiftUI
import CoreGraphics

/// Spacing tokens used across the UI. Tokens map directly to layout
/// primitives — use them instead of magic numbers.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let s:   CGFloat = 12
    static let m:   CGFloat = 16
    static let l:   CGFloat = 20
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48

    // MARK: - Layout primitives

    static let pageHorizontalInset: CGFloat = 20
    static let listRowHeight:        CGFloat = 64

    // MARK: - Corner radii

    static let sheetCornerRadius: CGFloat = 20
    static let cardCornerRadius:  CGFloat = 16
    static let pillCornerRadius:  CGFloat = 999

    // MARK: - Player artwork

    static let albumArtLarge:  CGFloat = 280
    static let albumArtMedium: CGFloat = 80
    static let albumArtSmall:  CGFloat = 48

    // MARK: - Symbols

    static let iconSmall:  CGFloat = 18
    static let iconBase:   CGFloat = 22
    static let iconLarge:  CGFloat = 28
}
