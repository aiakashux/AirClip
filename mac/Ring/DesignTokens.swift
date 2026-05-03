import SwiftUI
import AppKit

// MARK: - Color Tokens

extension Color {

    // MARK: Backgrounds

    static let bgBase     = Color.adaptive("#1C1C1E", light: "#F2F2F7")
    static let bgElevated = Color.adaptive("#232327", light: "#FFFFFF")
    static let bgFloating = Color.adaptive("#2A2A2E", light: "#FFFFFF")
    static let bgOverlay  = Color.adaptive("#161618", light: "#161618")  // modal scrim — use at 0.70 opacity

    // MARK: Text — 5 tiers, all as primary-color multiplied opacity

    static let textPrimary   = Color.primary.opacity(0.88)  // titles, main content
    static let textSubtle    = Color.primary.opacity(0.70)  // toast, secondary labels
    static let textSecondary = Color.primary.opacity(0.45)  // subtitles, captions
    static let textTertiary  = Color.primary.opacity(0.28)  // section headers, placeholders
    static let textLink      = Color(hex: "#FF6363")

    // MARK: Borders — 4 tiers

    static let borderSubtle  = Color.primary.opacity(0.06)
    static let borderDefault = Color.primary.opacity(0.10)
    static let borderFocus   = Color.primary.opacity(0.20)
    static let borderDash    = Color.primary.opacity(0.15)

    // MARK: Interactive fills

    static let selectionFill   = Color(red: 1, green: 0.384, blue: 0.384, opacity: 0.15)
    static let hoverFill       = Color.primary.opacity(0.05)
    static let activeFill      = Color.primary.opacity(0.08)
    static let segmentSelected = Color.primary.opacity(0.10)

    // MARK: Accent — signal only, not decoration

    static let accent         = Color(hex: "#FF6363")
    static let accentDeep     = Color(hex: "#E5342A")  // hover / pressed state

    // MARK: Semantic status

    static let encryptedGreen = Color(hex: "#59D499")
    static let syncBlue       = Color(hex: "#56C2FF")  // single blue — also used for URL text
    static let warningYellow  = Color(hex: "#FFC531")
    static let destructiveRed = Color(hex: "#E5342A")  // same hue as accentDeep, semantic alias

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
    static let ringLargeTitle = Font.system(size: 26, weight: .bold,     design: .default)
    static let ringTitle1     = Font.system(size: 20, weight: .semibold, design: .default)
    static let ringTitle2     = Font.system(size: 17, weight: .semibold, design: .default)

    // Body
    static let ringBody       = Font.system(size: 13, weight: .regular,  design: .default)
    static let ringBodyMedium = Font.system(size: 13, weight: .medium,   design: .default)

    // Small
    static let ringCaption    = Font.system(size: 11, weight: .regular,  design: .default)
    static let ringCaptionMed = Font.system(size: 11, weight: .medium,   design: .default)
    static let ringMono       = Font.system(size: 12, weight: .regular,  design: .monospaced)

    // Search / Input
    static let ringSearch     = Font.system(size: 15, weight: .regular,  design: .default)
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
    static let ringDefault = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: Duration.short)

    /// Entrances from below (popovers, sheets)
    static let ringEntrance = Animation.timingCurve(0.16, 1, 0.3, 1, duration: Duration.short)

    /// Hover fills, selection state — instant feel
    static func ringInstant(_ duration: Double = Duration.instant) -> Animation {
        .spring(response: duration * 1.5, dampingFraction: 0.82)
    }

    /// Opacity breathe for live/syncing state — use with .repeatForever(autoreverses: true)
    static let ringPulse = Animation.easeInOut(duration: 1.5)
}
