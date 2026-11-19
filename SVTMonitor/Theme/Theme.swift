import SwiftUI
import UIKit

/// Palette, type and surfaces.
///
/// The look follows Apple Health and the Watch Heart Rate app rather than a
/// custom "brand" skin: system grouped backgrounds, flat surfaces, SF Pro for
/// words and SF Rounded only for the numbers people actually read. Every color
/// has a dark-mode value, because episodes often happen at night.
///
/// Every text color here meets WCAG 2.2 AA (4.5:1) against both the grouped
/// background and the card surface, in light and dark mode. Ratios are noted
/// beside each value so a change that breaks contrast is easy to spot.
enum Theme {

    // MARK: - Palette

    /// Heart-rate data and primary actions. A rose red, the color people
    /// already associate with heart data on iOS.
    static let accent = dynamic(light: 0xC8364A, dark: 0xFF6B7A) // 4.6 / 6.2
    /// Lighter accent for fills, area charts and the resting heart.
    static let accentSoft = dynamic(light: 0xE5677A, dark: 0xFF8F9A)
    /// Possible episode / over-threshold. Amber so it reads as "pay attention"
    /// and stays distinct from ordinary heart-rate red.
    static let alert = dynamic(light: 0xA84A00, dark: 0xFF9F43) // 5.0 / 8.3
    /// Lighter alert for fills and threshold lines.
    static let alertSoft = dynamic(light: 0xF08C3A, dark: 0xFFB46B)
    /// Breathing guide only. A cool teal, as in Apple's Breathe, so calm mode
    /// doesn't put a red-and-amber screen in front of someone mid-episode.
    static let calm = dynamic(light: 0x16777A, dark: 0x5CD1CC) // 4.8 / 9.3
    /// "Monitoring" status. System green is only 2.2:1 on white, too faint
    /// for text, so light mode uses a deeper green.
    static let ok = dynamic(light: 0x1E7B34, dark: 0x30D158) // 4.8 / 8.4
    /// Text and icons drawn on top of a filled accent, alert or calm surface.
    /// White on the light-mode fills; black on the brighter dark-mode fills,
    /// where white would drop below 3:1.
    static let onFill = dynamic(light: 0xFFFFFF, dark: 0x000000)

    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(uiColor: .label)
    /// Slightly darker than `.secondaryLabel`, which is about 3.4:1 on white.
    static let inkSecondary = dynamic(light: 0x6C6C70, dark: 0x98989F) // 4.7 / 6.0
    static let hairline = Color(uiColor: .separator)

    // MARK: - Metrics

    /// Matches inset-grouped list cells, so cards and lists sit together.
    static let cornerRadius: CGFloat = 12

    // MARK: - Typography

    /// SF Pro at a base size that grows with the user's Dynamic Type setting.
    /// (`RootView` rebuilds the tree when that setting changes, so text
    /// resizes live.)
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        scaled(.systemFont(ofSize: size, weight: uiWeight(weight)), base: size)
    }

    /// SF Rounded with fixed-width digits, for heart rates, durations and
    /// counts, so values don't jitter as they update.
    static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        let rounded = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        return scaled(rounded, base: size).monospacedDigit()
    }

    // MARK: - Helpers

    /// Display sizes (the 80pt reading, the breathing countdown) are already
    /// huge, so they grow less; at full accessibility scaling they would
    /// otherwise push everything else off screen. Body-sized text scales
    /// without a cap.
    private static func scaled(_ font: UIFont, base: CGFloat) -> Font {
        let metrics = UIFontMetrics.default
        if base >= 30 {
            return Font(metrics.scaledFont(for: font, maximumPointSize: base * 1.4))
        }
        return Font(metrics.scaledFont(for: font))
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Reusable surface styling

/// A flat grouped surface, the same shape as an inset-grouped list cell.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

extension View {
    /// Applies the standard app background that fills the safe area.
    func appBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}
