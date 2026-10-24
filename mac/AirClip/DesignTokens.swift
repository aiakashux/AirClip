import SwiftUI
import AppKit

// MARK: - Color Tokens

extension Color {

    // MARK: Backgrounds

    static let bgBase     = adaptive("#101113", light: "#F4F5F7")
    static let bgElevated = adaptive("#1C1D20", light: "#FFFFFF")
    static let bgFloating = adaptive("#25262A", light: "#F8F9FB")
    static let mainWindowShell = adaptive("#101113", light: "#F9FAFB")
    static let mainWindowBrand = adaptive("#F2F3F5", light: "#232E43")
    static let mainWindowMeta = adaptive("#ADB2BC", light: "#868C98")
    static let mainWindowSearchFill = adaptive("#25262A", light: "#F7F8F9")
    static let bgOverlay  = adaptive("#161618", light: "#E8EAEE")  // modal scrim — use at 0.70 opacity
    static let glassTint  = adaptive("#FFFFFF", light: "#FFFFFF")

    // MARK: Text — 5 tiers, all as primary-color multiplied opacity

    static let textPrimary   = adaptive("#F2F3F5", light: "#15161A")  // titles, main content
    static let textSubtle    = adaptive("#CACDD3", light: "#30343B")  // toast, secondary labels
    static let textSecondary = adaptive("#ADB2BC", light: "#5B6270")  // subtitles, captions
    static let textTertiary  = adaptive("#A6ABB5", light: "#626B79")  // readable metadata and placeholders
    static let textLink      = adaptive("#A59DFF", light: "#6740BF")

    // MARK: Borders — 4 tiers

    static let borderSubtle  = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.08)
    static let borderDefault = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.14)
    static let borderFocus   = adaptive("#A59DFF", light: "#6740BF")
    static let borderDash    = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.18)

    // MARK: Interactive fills

    static let selectionFill   = accent.opacity(0.14)
    static let hoverFill       = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.06)
    static let activeFill      = adaptive("#FFFFFF", light: "#1C1D20").opacity(0.10)
    static let segmentSelected = adaptive("#36373A", light: "#E5E7EB")
    static let sidebarHover    = adaptive("#FFFFFF", light: "#FAFAFA", darkAlpha: 0.06, lightAlpha: 0.40)
    static let sidebarSelected = adaptive("#2A2B2E", light: "#E8E9EA")
    static let sidebarSelectedBorder = adaptive("#404248", light: "#EEF1F1")
    static let listItemHover = adaptive("#26272B", light: "#F4F5F5")
    static let listItemSelected = adaptive("#2A2B2E", light: "#FAFAFA")
    static let listItemSelectedBorder = adaptive("#404248", light: "#E7E7E7")

    // MARK: Accent — signal only, not decoration

    static let accent         = adaptive("#A59DFF", light: "#6740BF")  // foreground / focus
    static let accentDeep     = Color(hex: "#6740BF")                   // filled controls
    static let primaryButtonFill = Color(hex: "#000000")                // filled primary buttons

    static let onDestructive = adaptive("#101113", light: "#FFFFFF")

    // MARK: Semantic status

    static let encryptedGreen = adaptive("#6CE0A8", light: "#167B4B")
    static let syncBlue       = adaptive("#70CBFF", light: "#006FA8")  // single blue — also used for URL text
    static let warningYellow  = adaptive("#FFD45C", light: "#8A5B00")
    static let destructiveRed = adaptive("#FF5B55", light: "#B42318")

    // MARK: Hex color parser (optional — for user-supplied hex strings like clipboard color items)

    static func parseHex(_ hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = h.range(of: #"^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}(?:\s*,\s*(?:0|1|0?\.\d+))?\s*\)$"#, options: .regularExpression) {
            let values = h[range].drop { $0 != "(" }.dropFirst().dropLast()
                .split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard values.count == (h.hasPrefix("rgba") ? 4 : 3), values.prefix(3).allSatisfy({ (0...255).contains($0) }) else {
                return nil
            }
            return Color(
                red: values[0] / 255,
                green: values[1] / 255,
                blue: values[2] / 255,
                opacity: values.count == 4 ? values[3] : 1
            )
        }
        if !h.hasPrefix("#") {
            guard h.count == 6, h.allSatisfy(\.isHexDigit), h.contains(where: ("A"..."F").contains), h == h.uppercased() else {
                return nil
            }
        }
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        if h.count == 3 || h.count == 4 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6 || h.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        if h.count == 6 {
            return Color(
                red: Double((rgb >> 16) & 0xFF) / 255,
                green: Double((rgb >> 8) & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255
            )
        }
        return Color(
            red: Double((rgb >> 24) & 0xFF) / 255,
            green: Double((rgb >> 16) & 0xFF) / 255,
            blue: Double((rgb >> 8) & 0xFF) / 255,
            opacity: Double(rgb & 0xFF) / 255
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

    private static func adaptive(
        _ dark: String,
        light: String,
        darkAlpha: CGFloat = 1,
        lightAlpha: CGFloat = 1
    ) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let h = (isDark ? dark : light).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: h).scanHexInt64(&int)
            return NSColor(
                srgbRed: CGFloat((int & 0xFF0000) >> 16) / 255,
                green:   CGFloat((int & 0x00FF00) >> 8)  / 255,
                blue:    CGFloat( int & 0x0000FF)         / 255,
                alpha:   isDark ? darkAlpha : lightAlpha
            )
        }))
    }
}

// MARK: - Typography

extension Font {
    // Display
    static let airClipLargeTitle = Font.custom("Beary", size: 26)
    static let airClipTitle1     = Font.custom("Beary", size: 20)
    static let airClipTitle2     = Font.custom("Beary", size: 17)

    // Body
    static let airClipBody       = Font.system(size: 13, weight: .regular,  design: .default)
    static let airClipBodyMedium = Font.custom("Beary", size: 13)

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
    static let windowMinWidth:      CGFloat = 940
    static let windowDefaultWidth:  CGFloat = 940

    // Search bar
    static let searchBarHeight:     CGFloat = 44
    static let searchBarPadding:    CGFloat = 16

    // List rows
    static let rowHeight:           CGFloat = 52
    static let rowPaddingH:         CGFloat = 16
    static let rowIconSize:         CGFloat = 28
    static let rowIconCornerRadius: CGFloat = Radius.sm       // 6
    static let rowIconGap:          CGFloat = 10

    // Panels
    static let sidebarWidth:        CGFloat = 56
    static let panelCornerRadius:   CGFloat = Radius.md       // 8
    static let popoverCornerRadius: CGFloat = Radius.md       // 8

    // Section headers
    static let sectionHeaderPaddingTop:    CGFloat = Spacing.lg   // 20
    static let sectionHeaderPaddingBottom: CGFloat = Spacing.xxs  // 4
    static let sectionHeaderPaddingH:      CGFloat = 24

    // Segmented control
    static let segmentCornerRadius: CGFloat = Radius.sm       // 6
    static let segmentPaddingH:     CGFloat = Spacing.sm      // 12
    static let segmentPaddingV:     CGFloat = Spacing.xxs     // 4

    // Action bar
    static let actionBarHeight:     CGFloat = 44
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
