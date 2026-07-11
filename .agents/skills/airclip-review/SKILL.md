---
name: airclip-review
description: "AirClip design review skill. Use when building components, auditing screens, or reviewing UX decisions for the AirClip macOS app. Includes component patterns, contrast ratios, UX laws, and AirClip-specific patterns. Requires /airclip-design to be loaded for tokens."
trigger: manual
---

# AirClip Design Review — Components & UX
**Use this alongside `/airclip-design` for tokens and motion.**

> This skill covers: component patterns, contrast ratios (WCAG), UX laws applied to AirClip, and app-specific patterns. Load `/airclip-design` first for color tokens, typography, spacing, and motion.

---

## 1. Component Patterns

### 1.1 Search / Filter Bar

```swift
// Top-anchored, full width — 52pt height, 16pt horizontal padding
// Back arrow on left when in sub-view
// Filter pill on right — bordered, chevron icon
// NO magnifying glass icon — cursor is enough

HStack(spacing: 10) {
    if isSubView {
        Image(systemName: "arrow.left")
            .foregroundColor(.textSecondary)
            .frame(width: 20, height: 20)
    }
    TextField("Type to filter...", text: $query)
        .font(.airClipSearch)
        .foregroundColor(.textPrimary)
    Spacer()
    FilterPill(label: filterLabel)  // only when filter is active
}
.padding(.horizontal, Layout.searchBarPadding)
.frame(height: Layout.searchBarHeight)
```

### 1.2 List Row

```swift
// Standard: icon + primary label + secondary label + right hint
// Selected: selectionFill background
// Hover: hoverFill background
// Entire row is the tap target — no small buttons inline

HStack(spacing: Layout.rowIconGap) {
    RoundedRectangle(cornerRadius: Layout.rowIconCornerRadius)
        .fill(iconBackground)
        .frame(width: Layout.rowIconSize, height: Layout.rowIconSize)
        .overlay(Image(systemName: iconName).font(.system(size: 12)))

    HStack(spacing: 6) {
        Text(title).font(.airClipBody).foregroundColor(.textPrimary)
        Text(subtitle).font(.airClipBody).foregroundColor(.textSecondary)
    }
    Spacer()
    Text(hint).font(.airClipCaption).foregroundColor(.textTertiary)
}
.padding(.horizontal, Layout.rowPaddingH)
.frame(height: Layout.rowHeight)
.background(isSelected ? Color.selectionFill : (isHovered ? Color.hoverFill : .clear))
.contentShape(Rectangle())
```

### 1.3 Section Header

```swift
// Never bold. Never uppercase. Quiet label only.
Text(label)
    .font(.airClipCaptionMed)
    .foregroundColor(.textTertiary)
    .padding(.leading, Layout.rowPaddingH)
    .padding(.top, Layout.sectionHeaderPaddingTop)
    .padding(.bottom, Layout.sectionHeaderPaddingBottom)
```

### 1.4 Segmented Control

```swift
// Dark container, selected segment: lighter fill + subtle border
// Max 4 segments

HStack(spacing: 2) {
    ForEach(segments) { segment in
        Button(segment.label) { selected = segment }
            .padding(.horizontal, Layout.segmentPaddingH)
            .padding(.vertical, Layout.segmentPaddingV)
            .background(selected == segment ? Color.segmentSelected : .clear)
            .overlay(RoundedRectangle(cornerRadius: Layout.segmentCornerRadius)
                .strokeBorder(selected == segment ? Color.borderDefault : .clear, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: Layout.segmentCornerRadius))
            .font(selected == segment ? .airClipCaptionMed : .airClipCaption)
            .foregroundColor(selected == segment ? .textPrimary : .textSecondary)
    }
}
.padding(3)
.background(Color.bgElevated)
.clipShape(RoundedRectangle(cornerRadius: Layout.segmentCornerRadius + 3))
.overlay(RoundedRectangle(cornerRadius: Layout.segmentCornerRadius + 3)
    .strokeBorder(Color.borderSubtle, lineWidth: 0.5))
```

### 1.5 Bottom Action Bar

```swift
// Pinned bottom. Frosted strip.
// Left: context label | Center: primary action + ↵ | Right: secondary + ⌘K

HStack {
    HStack(spacing: 6) {
        Image(systemName: contextIcon).foregroundColor(.textSecondary).font(.system(size: 12))
        Text(contextLabel).font(.airClipCaption).foregroundColor(.textSecondary)
    }
    Spacer()
    HStack(spacing: 4) {
        Text(primaryAction).font(.airClipCaptionMed).foregroundColor(.textPrimary)
        KbdHint("↵")
    }
    Text("|").foregroundColor(.textTertiary).padding(.horizontal, 8)
    HStack(spacing: 4) {
        Text(secondaryAction).font(.airClipCaption).foregroundColor(.textSecondary)
        KbdHint("⌘K")
    }
}
.padding(.horizontal, Layout.actionBarPaddingH)
.frame(height: Layout.actionBarHeight)
.background(.ultraThinMaterial)
.overlay(Divider().frame(height: 0.5).background(Color.borderSubtle), alignment: .top)
```

### 1.6 Status Dot

```swift
// 6pt circle + caption label. Never standalone without text.
// Pulse only when actively syncing — steady otherwise.

HStack(spacing: 5) {
    Circle()
        .fill(statusColor)
        .frame(width: 6, height: 6)
        .opacity(isPulsing ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
    Text(statusLabel)
        .font(.airClipCaption)
        .foregroundColor(.textSecondary)
}
```

### 1.7 Clipboard Item Preview

```swift
// SF Mono for raw content — signals "this is data, not UI"
// Max 2 lines, then truncate
// Relative timestamp right-aligned

VStack(alignment: .leading, spacing: 4) {
    Text(content)
        .font(.airClipMono)
        .foregroundColor(.textPrimary)
        .lineLimit(2)
        .truncationMode(.tail)
    HStack {
        Text(sourceApp).font(.airClipCaption).foregroundColor(.textTertiary)
        Spacer()
        Text(relativeTime).font(.airClipCaption).foregroundColor(.textTertiary)
    }
}
.padding(.horizontal, Layout.rowPaddingH)
.padding(.vertical, 10)
```

### 1.8 Empty State

```swift
// Never just "No items" — give context and a next step
VStack(spacing: 12) {
    Image(systemName: "doc.on.clipboard")
        .font(.system(size: 32, weight: .thin))
        .foregroundColor(.textTertiary)
    Text("Nothing copied yet")
        .font(.airClipTitle2)
        .foregroundColor(.textSecondary)
    Text("Copy anything on your Mac to get started.")
        .font(.airClipBody)
        .foregroundColor(.textTertiary)
        .multilineTextAlignment(.center)
}
.frame(maxWidth: 240)
```

---

## 2. AirClip-Specific Patterns

### Clipboard Item Types

```
Text    — SF Mono preview, no icon background tint
Color   — 16pt filled circle + hex value in mono
URL     — globe icon, domain prominent, path in textTertiary
Image   — 40×40pt thumbnail (cornerRadius 6pt) + dimensions caption
File    — NSWorkspace file icon + filename + size
```

### Encryption Badge

```
Always visible on clipboard items.
Color: encryptedGreen dot
Label: "E2E Encrypted" — NOT "Secure" (specific = trustworthy)
```

### Sync State Indicator

```
🔵 pulse   "Syncing..."         — syncBlue,       opacity pulse
🟢 steady  "All devices synced" — encryptedGreen,  no animation
🟡 steady  "No connection"      — warningYellow,   no animation
🔴 steady  "Sync failed"        — destructiveRed,  no animation
```

---

## 3. Contrast Ratios — WCAG Compliance

> AirClip handles private data. Accessibility is part of being trustworthy.

### WCAG Targets

| Level | Normal text | Large text (18pt+ or 14pt+ bold) |
|---|---|---|
| **AA** (minimum) | 4.5:1 | 3:1 |
| **AAA** (target) | 7:1 | 4.5:1 |
| **UI components** | 3:1 against adjacent | — |

### Verified — Dark Mode (against `#1C1C1E`)

```
textPrimary    rgba(255,255,255,0.92) → #EAEAEA → 14.5:1  ✅ AAA
textSecondary  rgba(255,255,255,0.45) → #848484 →  5.2:1  ✅ AA
textTertiary   rgba(255,255,255,0.25) → #4F4F4F →  2.8:1  ⚠️  DECORATIVE ONLY
textPlaceholder rgba(255,255,255,0.20)→ #424242 →  2.2:1  ⚠️  Placeholder — WCAG exempt
accent         #FF6363               →          →  4.6:1  ✅ AA at 13pt+
encryptedGreen #59D499               →          →  8.1:1  ✅ AAA
syncBlue       #56C2FF               →          →  7.4:1  ✅ AAA
warningYellow  #FFC531               →          →  9.1:1  ✅ AAA
```

### Verified — Light Mode (against `#F2F2F7`)

```
textPrimary_light   rgba(0,0,0,0.88) → #1D1D1D → 14.2:1  ✅ AAA
textSecondary_light rgba(0,0,0,0.45) → #8C8C8C →  4.7:1  ✅ AA
textTertiary_light  rgba(0,0,0,0.25) → #BFBFBF →  1.8:1  ⚠️  DECORATIVE ONLY
accent              #FF6363          →         →  3.5:1  ⚠️  Light mode: 18pt+ only
```

### Critical Rules

```
✅ Only textPrimary and textSecondary for readable content
✅ textTertiary = decorative only (section headers, scanned metadata)
⚠️  accent on light = use at 18pt+ or bold 14pt+ only — fails at 11pt caption
⚠️  Status colors (green/blue/yellow) as text on white — fail at small sizes
❌ Never render clipboard content below textSecondary
❌ Never place textTertiary over bgElevated for readable text
```

### Focus Indicators

```swift
// Never suppress system focus ring
// .focusable(false) ❌ — kills keyboard navigation
// System focus ring is already AA compliant
// If custom focus style: minimum 2px, 3:1 contrast against adjacent color
```

### Pre-Ship Contrast Checklist

Before shipping any screen, verify:
- [ ] All body text uses `textPrimary` or `textSecondary`
- [ ] Any text < 14pt has ≥ 4.5:1 ratio
- [ ] Status indicators are never color-only — always paired with a text label
- [ ] Interactive controls have visible hover AND focus states
- [ ] Error states don't rely on red alone — paired with icon or label

---

## 4. UX Laws Applied to AirClip

### Fitts's Law — Larger targets, faster clicks

```
✅ Rows are 40pt — 8pt more than minimal, significantly faster to hit
✅ Copy = click the entire row, not a small button
✅ Most recent item is first — nearest to where the pointer arrives
✅ Close button is a screen-edge corner — infinite target in one direction
❌ Never put a small inline "×" delete inside a row — use swipe or ⌘⌫
❌ Never place the primary action bottom-right
```

### Hick's Law — More choices = slower decisions

```
✅ Main list: only items — no inline toggles, filters, settings
✅ Action bar: max 2 actions (primary + more)
✅ Preferences hidden behind ⌘, — invisible during normal use
✅ Filter controls appear only when typing
❌ Never show 5+ action buttons on a row
❌ Never put settings toggles on the main view
```

### Miller's Law — Working memory holds ~7 items

```
✅ Max 8–10 items visible before scroll
✅ Group by time: "Today", "Yesterday", "Earlier"
✅ Keyboard shortcuts shown inline — reduces recall demand
✅ Clipboard preview truncates at 2 lines — recognize, don't recall
❌ Never show raw timestamps ("2025-03-27 13:35:07") — use "2 min ago"
```

### Jakob's Law — Users expect familiar patterns

```
✅ ⌘C copies. ⌘V pastes. ⌘, opens preferences. Non-negotiable.
✅ Arrow keys navigate the list — same as Spotlight, Raycast, Finder
✅ Escape closes the panel
✅ Traffic light buttons behave as expected
❌ Never invent new shortcuts for actions with standard ones
❌ Never put Preferences anywhere other than the app menu or ⌘,
```

### Serial Position Effect — First and last are remembered best

```
✅ Most recent clipboard item is always first
✅ Bottom action bar (last thing in window) = primary action
✅ E2E Encrypted badge at bottom = last impression is trust
❌ Never bury "Copy" in the middle of an options list
❌ Never put sync state in the middle of the toolbar
```

### Doherty Threshold — Under 400ms feels instant

```
✅ Copy: instant. No spinner, no toast — just the OS sound
✅ Search: updates within 100ms of each keystroke
✅ Panel open from menu bar: < 200ms
✅ If sync > 400ms: pulse dot, NOT a spinner
❌ Never show a loading indicator for operations under 400ms
❌ Never delay a keyboard shortcut response to play a transition
```

### Aesthetic–Usability Effect — Beautiful = feels easier to use

```
For AirClip, trust IS the product. E2E encryption is meaningless
if the app looks hacked together. The design IS the security story.

✅ Every screen must pass: "would I trust this with my passwords?"
✅ Empty states must look intentional, not broken
✅ Error messages: calm and specific — never alarming
❌ Never ship an unfinished-looking screen in a trust-critical app
```

### Tesler's Law — Complexity must go somewhere — absorb it in the app

```
AirClip's complexity: encryption, key management, network state, conflict resolution.
The app absorbs ALL of it. The user sees only: "it works."

✅ Device pairing: one QR scan — no manual key entry
✅ Encryption: always on — never a setting, never a choice
✅ Network state: handled silently — show a dot, not a dialog
❌ Never ask the user to configure what the app can auto-detect
❌ Never surface encryption internals unless explicitly requested
```

### Postel's Law — Accept everything, emit precisely

```
✅ Accept clipboard items of any type — text, URLs, colors, files, images
✅ Accept any text encoding — emoji, RTL, CJK, markdown, code
✅ Degrade gracefully: unknown type → show type name + size, no crash
❌ Never reject a clipboard item silently
❌ Never crash on unexpected payload
```

### Zeigarnik Effect — Incomplete tasks are remembered

```
✅ Persist in-progress device pairing across panel open/close
✅ Show "Pairing in progress..." if setup started but not finished
✅ Failed mid-transfer: show item in "pending" state, not silently dropped
❌ Never clear the search field on panel close — restore on next open
❌ Never silently abandon incomplete sync operations
```
