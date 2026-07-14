import SwiftUI

/// Type scale. All views pull font / weight / size from here.
/// Uses SF Pro with `.rounded` for display sizes for friendlier feel.
enum Typography {

    static let display     = Font.system(size: 34, weight: .heavy,  design: .rounded)
    static let title1      = Font.system(size: 28, weight: .bold,   design: .rounded)
    static let title2      = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3      = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline    = Font.system(size: 17, weight: .semibold, design: .default)
    static let body        = Font.system(size: 17, weight: .regular,  design: .default)
    static let callout     = Font.system(size: 16, weight: .regular,  design: .default)
    static let subhead     = Font.system(size: 15, weight: .regular,  design: .default)
    static let footnote    = Font.system(size: 13, weight: .regular,  design: .default)
    static let caption1    = Font.system(size: 12, weight: .regular,  design: .default)
    static let caption2    = Font.system(size: 11, weight: .regular,  design: .default)
    static let button      = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let monoCaption = Font.system(size: 12, weight: .medium,  design: .monospaced)
}
