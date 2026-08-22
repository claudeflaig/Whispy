import SwiftUI

extension Font {
    /// Raycast's primary UI typeface. Inter Variable is bundled with Whispy so the
    /// popup and settings render consistently on every supported Mac.
    static func raycast(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("Inter Variable", size: size).weight(weight)
    }

    /// Raycast-style technical typography for shortcuts, keys and paths.
    static func raycastMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let family: String
        if weight == .semibold || weight == .bold || weight == .heavy || weight == .black {
            family = "Geist Mono SemiBold"
        } else if weight == .medium {
            family = "Geist Mono Medium"
        } else {
            family = "Geist Mono"
        }
        return .custom(family, size: size)
    }
}

extension Color {
    /// Raycast Red — intentionally used as punctuation rather than a pervasive tint.
    static let raycastRed = Color(red: 1.0, green: 0.388, blue: 0.388)
}
