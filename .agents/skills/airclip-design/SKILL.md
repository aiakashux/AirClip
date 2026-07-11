---
name: airclip-design
description: "AirClip core design system. Use when building ANY UI for the AirClip macOS app — colors, typography, spacing, borders, shadows, motion. Companion: /airclip-review for component patterns, UX laws, contrast audit."
trigger: manual
---

# AirClip Design System — Core
**Raycast-inspired. Native macOS. Premium without decoration.**

> You are building AirClip — a secure cross-device clipboard syncing tool. The design must feel like it belongs in the same family as Raycast: invisible until needed, precise, fast, and trusted. Every decision should earn its place. If it doesn't serve the user's focus, remove it.

> **Companion skill:** For component patterns, UX laws, and contrast audit → call `/airclip-review`

---

## 0. Philosophy

1. **The window IS the content.** No decorative chrome. No gradients for their own sake. The UI recedes so the content leads.
2. **Density with rhythm.** High information density but every row, gap, and label has a deliberate weight. The eye flows without effort.
3. **Restraint on accent.** The brand color (`#FF6363`) is a signal, not decoration. It marks selection, danger, and live state — nothing else.
4. **Motion as response, not performance.** Animations confirm actions. They are short, directional, and use Apple's easeOutQuart. No bounce. No spin. No blur transitions. No spring physics.

---

## 1. Color Tokens

### Dark Mode (Primary — default)

```swift
// SwiftUI Color extensions — add to Color+AirClip.swift

// Backgrounds — layered surfaces, NOT pure black
static let bgBase        = Color(hex: "#1C1C1E")   // window floor
static let bgElevated    = Color(hex: "#232327")   // panels, lists
static let bgFloating    = Color(hex: "#2A2A2E")   // popovers, dropdowns
static let bgOverlay     = Color(hex: "#161618")   // modal scrim (0.7 opacity)

// Selection & States
static let selectionFill   = Color(red: 1, green: 0.384, blue: 0.384, opacity: 0.15)
static let hoverFill       = Color(white: 1, opacity: 0.05)
static let activeFill      = Color(white: 1, opacity: 0.08)
static let segmentSelected = Color(white: 1, opacity: 0.10)

// Text — never pure white
static let textPrimary     = Color(white: 1, opacity: 0.92)   // titles, main content
static let textSecondary   = Color(white: 1, opacity: 0.45)   // subtitles, captions
static let textTertiary    = Color(white: 1, opacity: 0.25)   // section headers — decorative only
static let textPlaceholder = Color(white: 1, opacity: 0.20)   // input placeholders
static let textLink        = Color(hex: "#FF6363")

// Borders — always translucent, never opaque
static let borderSubtle    = Color(white: 1, opacity: 0.06)
static let borderDefault   = Color(white: 1, opacity: 0.10)
static let borderFocus     = Color(white: 1, opacity: 0.20)
static let borderDash      = Color(white: 1, opacity: 0.15)

// Accent — USE SPARINGLY. Only selection, live state, destructive
static let accent          = Color(hex: "#FF6363")
static let accentDeep      = Color(hex: "#E5342A")
static let accentGlow      = Color(red: 1, green: 0.384, blue: 0.384, opacity: 0.08)

// Semantic status colors
static let encryptedGreen  = Color(hex: "#59D499")   // E2E secure
static let syncBlue        = Color(hex: "#56C2FF")   // live sync
static let warningYellow   = Color(hex: "#FFC531")   // offline / warning
static let destructiveRed  = Color(hex: "#E5342A")   // delete / revoke
```

### Light Mode

```swift
static let bgBase_light       = Color(hex: "#F2F2F7")
static let bgElevated_light   = Color(hex: "#FFFFFF")
static let bgFloating_light   = Color(hex: "#FFFFFF")

static let selectionFill_light   = Color(red: 1, green: 0.384, blue: 0.384, opacity: 0.10)
static let hoverFill_light       = Color(black: 0, opacity: 0.04)
static let activeFill_light      = Color(black: 0, opacity: 0.07)
static let segmentSelected_light = Color(black: 0, opacity: 0.08)

static let textPrimary_light     = Color(black: 0, opacity: 0.88)
static let textSecondary_light   = Color(black: 0, opacity: 0.45)
static let textTertiary_light    = Color(black: 0, opacity: 0.25)
static let textPlaceholder_light = Color(black: 0, opacity: 0.20)

static let borderSubtle_light    = Color(black: 0, opacity: 0.06)
static let borderDefault_light   = Color(black: 0, opacity: 0.12)
static let borderFocus_light     = Color(black: 0, opacity: 0.25)
```

### Color Rules
- **Never** use `#FF6363` as a background fill on large surfaces
- **Never** use pure `#000000` or `#FFFFFF` as a surface color
- Semantic colors (`encryptedGreen`, `syncBlue`, `warningYellow`) are dots and icon tints only — never body text color
- `textTertiary` is decorative context only — section headers users scan, not read

---

## 2. Typography

**SF Pro exclusively.** No custom fonts. No Google Fonts.

```swift
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
```

**Rules:**
- List item title + subtitle: same size (13pt) — hierarchy is color, not size
- Section headers: 11pt medium, `textTertiary`, sentence case — NOT ALL CAPS
- Keyboard hints: 11pt regular, `textTertiary`, right-aligned
- Clipboard content: SF Mono 12pt — signals raw data
- Line height: 1.4× body, 1.2× UI labels
- Letter spacing: system default — no custom tracking

---

## 3. Spacing & Layout

**Base unit: 8pt.** All values multiples of 4pt minimum.

```swift
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16   // standard row padding
    static let lg:  CGFloat = 20
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Layout {
    // Window
    static let windowCornerRadius:  CGFloat = 12
    static let windowMinWidth:      CGFloat = 680
    static let windowDefaultWidth:  CGFloat = 760

    // Search bar
    static let searchBarHeight:     CGFloat = 52
    static let searchBarPadding:    CGFloat = 16

    // List rows
    static let rowHeight:           CGFloat = 40
    static let rowPaddingH:         CGFloat = 16
    static let rowIconSize:         CGFloat = 20
    static let rowIconCornerRadius: CGFloat = 5
    static let rowIconGap:          CGFloat = 10

    // Panels
    static let sidebarWidth:        CGFloat = 220
    static let panelCornerRadius:   CGFloat = 10
    static let popoverCornerRadius: CGFloat = 10

    // Section headers
    static let sectionHeaderPaddingTop:    CGFloat = 20
    static let sectionHeaderPaddingBottom: CGFloat = 4
    static let sectionHeaderPaddingH:      CGFloat = 16

    // Segmented control
    static let segmentCornerRadius: CGFloat = 6
    static let segmentPaddingH:     CGFloat = 12
    static let segmentPaddingV:     CGFloat = 5

    // Action bar
    static let actionBarHeight:     CGFloat = 40
    static let actionBarPaddingH:   CGFloat = 12
}
```

**Dividers:** 0.5pt hairline, `borderSubtle`, full bleed — never 1pt, never inset.

---

## 4. Borders & Surfaces

```swift
// Card / panel
RoundedRectangle(cornerRadius: Layout.panelCornerRadius)
    .fill(Color.bgElevated)
    .overlay(RoundedRectangle(cornerRadius: Layout.panelCornerRadius)
        .strokeBorder(Color.borderSubtle, lineWidth: 0.5))

// Floating popover
RoundedRectangle(cornerRadius: Layout.popoverCornerRadius)
    .fill(Color.bgFloating)
    .overlay(RoundedRectangle(cornerRadius: Layout.popoverCornerRadius)
        .strokeBorder(Color.borderDefault, lineWidth: 0.5))
    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)

// Input at rest / focused
.strokeBorder(Color.borderDefault, lineWidth: 1)   // rest
.strokeBorder(Color.borderFocus,   lineWidth: 1)   // focused

// Frosted glass (menu bar popover)
.background(.ultraThinMaterial)
.background(Color.bgFloating.opacity(0.85))

// Dashed drop zone
.strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
.foregroundColor(Color.borderDash)
```

---

## 5. Shadows

```swift
.shadow(color: .black.opacity(0.60), radius: 40, x: 0, y: 20)  // window
.shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 8)   // panel / card
.shadow(color: .black.opacity(0.50), radius: 20, x: 0, y: 6)   // dropdown
.shadow(color: .black.opacity(0.25), radius: 8,  x: 0, y: 2)   // buttons / badges

// NEVER shadow individual list rows or inner elements
// Shadows belong to floating containers only
```

---

## 6. Motion — The Most Important Section

> "Premium animation is the absence of bad animation."

### Timing Curves

```swift
// THE one curve — Apple easeOutQuart. Use for everything.
static let easeOutQuart = Animation.timingCurve(0.25, 0.46, 0.45, 0.94)

// Elements entering from below (popovers, sheets)
static let easeOutExpo  = Animation.timingCurve(0.16, 1, 0.3, 1)

// Opacity-only fades — never combine with transform
static let easeInOut    = Animation.easeInOut
```

### Duration Scale

```swift
enum Duration {
    static let instant: Double = 0.10   // hover fills, selection
    static let micro:   Double = 0.15   // row select, button press
    static let short:   Double = 0.20   // dropdown open, panel slide
    static let medium:  Double = 0.25   // window appear, view transition
    static let long:    Double = 0.35   // sheet present (sparingly)
}
```

### Motion Patterns

```swift
// Window appear
.transition(.asymmetric(
    insertion: .scale(scale: 0.96).combined(with: .opacity)
        .animation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.22)),
    removal: .scale(scale: 0.96).combined(with: .opacity)
        .animation(.easeIn(duration: 0.15))
))

// Dropdown appear
.transition(.asymmetric(
    insertion: .move(edge: .top).combined(with: .opacity)
        .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.20)),
    removal: .opacity.animation(.easeIn(duration: 0.12))
))

// Row selection — instant, native
withAnimation(.linear(duration: 0.0)) { selectedItem = item }

// Staggered list appear (initial load only)
.transition(.opacity.combined(with: .move(edge: .bottom)))
.animation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.18)
    .delay(Double(index) * 0.03))

// Sync pulse — opacity breathe, NOT scale
.opacity(isSyncing ? 0.5 : 1.0)
.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isSyncing)
```

### NEVER Use These

```
❌ spring() with bounce > 0
❌ rotation / spin on any element
❌ blur transitions
❌ scale > 1.0 (no overshoot)
❌ easeIn for entrances
❌ duration > 0.4s for any UI element
❌ wiggle, shake, rubber-band
❌ particle effects, confetti
❌ Any animation that draws attention to itself
```

---

## 7. Native macOS Rules

1. **Native window chrome.** Traffic light buttons standard. `.hiddenTitleBar` only for command-palette popup.
2. **Always both modes.** `@Environment(\.colorScheme)` — never hard-code dark or light.
3. **SF Symbols only.** Weight `.regular` or `.medium`. No custom icon fonts, no emoji as UI icons.
4. **Menu bar app.** Uses `NSPanel` / `.popover` — does NOT appear in Dock.
5. **Keyboard first.** Arrow keys navigate. ⌘K = actions. ⌘, = preferences. ⌘W = close. Escape = dismiss.
6. **Vibrancy.** `NSVisualEffectView` / `.ultraThinMaterial` for the popover background.
7. **Cursor.** `.pointingHand` on interactive elements. `.iBeam` on text. Never custom.

---

## 8. Anti-Patterns — What AirClip NEVER Does

```
❌ Pure black (#000000) backgrounds — use #1C1C1E
❌ Pure white (#FFFFFF) text — use rgba(255,255,255,0.92)
❌ Accent (#FF6363) as decoration — it's a signal only
❌ Corner radius > 12pt on main window
❌ Shadows on list rows or inner elements
❌ Bold section headers or ALL CAPS labels
❌ More than 2 font weights in a single view
❌ Custom color backgrounds on rows (except selectionFill)
❌ Animated icons (spinning, bouncing)
❌ Tooltips on obvious controls
❌ Progress bars for operations < 2s — use pulse opacity
❌ Modal dialogs for non-destructive actions
❌ Gradient text
❌ Custom scrollbars
❌ Blur-in / blur-out transitions
❌ Any animation > 400ms
```

---

## 9. Quick Reference

| Token | Dark | Light |
|---|---|---|
| bg.base | `#1C1C1E` | `#F2F2F7` |
| bg.elevated | `#232327` | `#FFFFFF` |
| bg.floating | `#2A2A2E` | `#FFFFFF` |
| text.primary | `rgba(255,255,255,0.92)` | `rgba(0,0,0,0.88)` |
| text.secondary | `rgba(255,255,255,0.45)` | `rgba(0,0,0,0.45)` |
| text.tertiary | `rgba(255,255,255,0.25)` | `rgba(0,0,0,0.25)` |
| border.subtle | `rgba(255,255,255,0.06)` | `rgba(0,0,0,0.06)` |
| border.default | `rgba(255,255,255,0.10)` | `rgba(0,0,0,0.12)` |
| accent | `#FF6363` | `#FF6363` |
| row.height | `40pt` | `40pt` |
| padding.h | `16pt` | `16pt` |
| corner.window | `12pt` | `12pt` |
| easing | `easeOutQuart(0.25, 0.46, 0.45, 0.94)` | same |
| duration.micro | `150ms` | `150ms` |
| duration.short | `200ms` | `200ms` |
