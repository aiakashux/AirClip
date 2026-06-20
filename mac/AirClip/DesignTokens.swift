import SwiftUI
import AppKit

// MARK: - Color Tokens

extension Color {

    // MARK: Backgrounds

    static let bgBase     = adaptive("#101113", light: "#F4F5F7")
    static let bgElevated = adaptive("#1C1D20", light: "#FFFFFF")
    static let bgFloating = adaptive("#25262A", light: "#F8F9FB")
    static let bgOverlay  = adaptive("#161618", light: "#E8EAEE")  // modal scrim — use at 0.70 opacity
    static let glassTint  = adaptive("#FFFFFF", light: "#FFFFFF")

    // MARK: Text — 5 tiers, all as primary-color multiplied opacity

    static let textPrimary   = adaptive("#F2F3F5", light: "#15161A")  // titles, main content
    static let textSubtle    = adaptive("#CACDD3", light: "#30343B")  // toast, secondary labels
    static let textSecondary = adaptive("#8F949D", light: "#5B6270")  // subtitles, captions
    static let textTertiary  = adaptive("#626875", light: "#7A8392")  // section headers, placeholders
    static let textLink      = adaptive("#FF7A7A", light: "#C92E2A")

    // MARK: Borders — 4 tiers

    static let borderSubtle  = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.08)
    static let borderDefault = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.14)
    static let borderFocus   = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.30)
    static let borderDash    = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.18)

    // MARK: Interactive fills

    static let selectionFill   = adaptive("#FF7A7A", light: "#C92E2A").opacity(0.16)
    static let hoverFill       = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.06)
    static let activeFill      = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.10)
    static let segmentSelected = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.12)

    // MARK: Accent — signal only, not decoration

    static let accent         = adaptive("#FF7A7A", light: "#B92421")
    static let accentDeep     = adaptive("#FF5B55", light: "#971A18")  // hover / pressed state

    // MARK: Semantic status

    static let encryptedGreen = adaptive("#6CE0A8", light: "#167B4B")
    static let syncBlue       = adaptive("#70CBFF", light: "#006FA8")  // single blue — also used for URL text
    static let warningYellow  = adaptive("#FFD45C", light: "#8A5B00")
    static let destructiveRed = adaptive("#FF5B55", light: "#B42318")

    // MARK: Hex color parser (optional — for user-supplied hex strings like clipboard color items)

    static func parseHex(_ hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.hasPrefix("#") else { return nil }
        h = String(h.dropFirst())
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6 || h.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        return Color(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }

    // MARK: Hex initialiser

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int & 0xFF0000) >> 16) / 255,
            green: Double((int & 0x00FF00) >> 8)  / 255,
            blue:  Double( int & 0x0000FF)         / 255
        )
    }

    private static func adaptive(_ dark: String, light: String) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let h = (isDark ? dark : light).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: h).scanHexInt64(&int)
            return NSColor(
                srgbRed: CGFloat((int & 0xFF0000) >> 16) / 255,
                green:   CGFloat((int & 0x00FF00) >> 8)  / 255,
                blue:    CGFloat( int & 0x0000FF)         / 255,
                alpha:   1
            )
        }))
    }
}

// MARK: - Typography (SF Pro only, no half-point sizes)

extension Font {
    // Display
    static let airClipLargeTitle = Font.system(size: 26, weight: .bold,     design: .default)
    static let airClipTitle1     = Font.system(size: 20, weight: .semibold, design: .default)
    static let airClipTitle2     = Font.system(size: 17, weight: .semibold, design: .default)

    // Body
    static let airClipBody       = Font.system(size: 13, weight: .regular,  design: .default)
    static let airClipBodyMedium = Font.system(size: 13, weight: .medium,   design: .default)

    // Small
    static let airClipCaption    = Font.system(size: 11, weight: .regular,  design: .default)
    static let airClipCaptionMed = Font.system(size: 11, weight: .medium,   design: .default)
    static let airClipMono       = Font.system(size: 12, weight: .regular,  design: .monospaced)

    // Search / Input
    static let airClipSearch     = Font.system(size: 15, weight: .regular,  design: .default)
}

// MARK: - Spacing (4pt base unit, 8pt rhythm)

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 20
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Radius (6 values + Capsule for pills)

enum Radius {
    static let xs:   CGFloat = 4   // dots, tiny badges, logo marks
    static let sm:   CGFloat = 6   // buttons, dropdowns, nav items, segment pills
    static let md:   CGFloat = 8   // inputs, rows, icon containers, modal inputs
    static let lg:   CGFloat = 12  // window chrome, panels, device cards
    static let xl:   CGFloat = 16  // search bar, modals, large containers
    static let card: CGFloat = 20  // popup clip cards
    // Pill shapes → use SwiftUI Capsule() directly
}

// MARK: - Layout

enum Layout {
    // Window
    static let windowCornerRadius:  CGFloat = Radius.lg      // 12
    static let windowMinWidth:      CGFloat = 680
    static let windowDefaultWidth:  CGFloat = 760

    // Search bar
    static let searchBarHeight:     CGFloat = 48
    static let searchBarPadding:    CGFloat = 16

    // List rows
    static let rowHeight:           CGFloat = 40
    static let rowPaddingH:         CGFloat = 16
    static let rowIconSize:         CGFloat = 20
    static let rowIconCornerRadius: CGFloat = Radius.sm       // 6
    static let rowIconGap:          CGFloat = Spacing.xs      // 8

    // Panels
    static let sidebarWidth:        CGFloat = 220
    static let panelCornerRadius:   CGFloat = Radius.md       // 8
    static let popoverCornerRadius: CGFloat = Radius.md       // 8

    // Section headers
    static let sectionHeaderPaddingTop:    CGFloat = Spacing.lg   // 20
    static let sectionHeaderPaddingBottom: CGFloat = Spacing.xxs  // 4
    static let sectionHeaderPaddingH:      CGFloat = Spacing.md   // 16

    // Segmented control
    static let segmentCornerRadius: CGFloat = Radius.sm       // 6
    static let segmentPaddingH:     CGFloat = Spacing.sm      // 12
    static let segmentPaddingV:     CGFloat = Spacing.xxs     // 4

    // Action bar
    static let actionBarHeight:     CGFloat = 40
    static let actionBarPaddingH:   CGFloat = Spacing.sm      // 12

    // Common component heights
    static let buttonHeight:        CGFloat = 36
    static let inputHeight:         CGFloat = 36
}

// MARK: - Duration

enum Duration {
    static let instant: Double = 0.10
    static let micro:   Double = 0.15
    static let short:   Double = 0.20
    static let medium:  Double = 0.25
    static let long:    Double = 0.35
}

// MARK: - Motion

extension Animation {
    /// Standard easing for all UI transitions — Apple easeOutQuart
    static let airClipDefault = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: Duration.short)

    /// Entrances from below (popovers, sheets)
    static let airClipEntrance = Animation.timingCurve(0.16, 1, 0.3, 1, duration: Duration.short)

    /// Hover fills, selection state — instant feel
    static func airClipInstant(_ duration: Double = Duration.instant) -> Animation {
        .spring(response: duration * 1.5, dampingFraction: 0.82)
    }

    /// Opacity breathe for live/syncing state — use with .repeatForever(autoreverses: true)
    static let airClipPulse = Animation.easeInOut(duration: 1.5)
}
