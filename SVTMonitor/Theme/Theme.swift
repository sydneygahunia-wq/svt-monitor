import SwiftUI

/// Central place for Sydney's brand palette, typography and spacing.
/// Colors are also mirrored in Assets.xcassets so the launch screen and
/// app icon stay in sync, but SwiftUI reads them from here for convenience.
enum Theme {

    // MARK: - Palette
    /// #eef2f7 — calm off-white app background.
    static let background = Color(red: 0xEE / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
    /// #2b3240 — slate ink for primary text.
    static let ink = Color(red: 0x2B / 255, green: 0x32 / 255, blue: 0x40 / 255)
    /// Muted slate for secondary text.
    static let inkSecondary = Color(red: 0x5A / 255, green: 0x63 / 255, blue: 0x75 / 255)
    /// #79aede — pastel blue, the primary brand accent.
    static let blue = Color(red: 0x79 / 255, green: 0xAE / 255, blue: 0xDE / 255)
    /// A slightly deeper blue for text/lines on light surfaces.
    static let blueDeep = Color(red: 0x4E / 255, green: 0x86 / 255, blue: 0xBE / 255)
    /// #eeb29c — soft peach, used only for episode / alert emphasis.
    static let peach = Color(red: 0xEE / 255, green: 0xB2 / 255, blue: 0x9C / 255)
    /// A deeper peach for peach text that needs contrast.
    static let peachDeep = Color(red: 0xC9 / 255, green: 0x77 / 255, blue: 0x5A / 255)
    /// Card / surface color that sits above the background.
    static let card = Color.white
    /// Hairline separators.
    static let hairline = Color(red: 0xD9 / 255, green: 0xDF / 255, blue: 0xE8 / 255)

    // MARK: - Metrics
    static let cornerRadius: CGFloat = 22
    static let cardShadow = Color(red: 0x2B / 255, green: 0x32 / 255, blue: 0x40 / 255).opacity(0.08)

    // MARK: - Typography (SF Rounded)
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Reusable surface styling

/// A soft rounded card used throughout the app for a calm, patient-friendly look.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 14, x: 0, y: 6)
    }
}

extension View {
    /// Applies the standard app background that fills the safe area.
    func appBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}
