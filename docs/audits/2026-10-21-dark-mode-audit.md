# Mac and Android dark-mode UI audit

Date: 21 October 2026

## Outcome and scope

Completed a source-level color audit of the Mac and Android UI, implemented the findings below, and verified builds and contrast calculations. This is **not a claim that every screen has passed a rendered accessibility audit**. No Android device/emulator was connected (`adb devices` returned an empty list). A temporary read-only launch of the configured Pixel_6a emulator was attempted, but the emulator exited with `No initial system image for this configuration!`. This pass did not capture or interactively verify the rebuilt Mac UI. Runtime checks remain listed below.

Existing uncommitted changes in icons, Mac window/layout code, and sync/history code were preserved. This report describes only the dark-mode work.

## Plan executed

1. Inventory screens, shared components, modal states, platform chrome, and auxiliary surfaces.
2. Research contrast requirements and measure actual color pairs, including alpha compositing.
3. Fix shared text tokens and targeted hard-coded colors; preserve QR scan contrast and user content.
4. Add regression checks, build both apps, run Android tests, and record remaining runtime coverage.

## Standard

Use 4.5:1 for normal text, including placeholders and metadata, and 3:1 for meaningful icons/control indicators. Decorative separators need not meet the control-indicator target when they are not needed to identify the control. Disabled controls and decorative artwork are distinct from readable content.

Sources: [W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [W3C non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

The local Airclip review guide's blanket placeholder exemption and precomputed color ratios are unreliable. This audit uses calculated sRGB luminance and composited colors instead. The skill files were not changed.

## Findings and fixes

| Finding | Before | Implemented fix / result |
|---|---|---|
| Tertiary metadata and placeholders fail on dark surfaces, both apps | `#626875`: 3.38:1 on base; 2.70:1 on floating | `#A6ABB5`: 6.56:1 on floating; minimum 4.80:1 across tested active/selected backgrounds |
| Secondary labels fail on selected surfaces | `#8F949D` on Mac segment: 3.91:1 | `#ADB2BC`: 5.59:1 on segment; minimum 5.20:1 across tested backgrounds |
| Onboarding ignores dark mode | Fixed white backdrops, dark titles, pale input fills | Semantic surfaces, titles, secondary labels, placeholders, back icons, and pairing controls on Mac; landing, camera-entry card, code display/input and tabs on Android |
| Android displayed pairing code nearly disappears | `#F2F3F5` digits on `#F5F5F5`: 1.02:1 | Floating dark background with primary text |
| Destructive button labels fail, both apps | White on `#FF5B55`: 3.05:1 | Dark ink on dark-mode red: 6.19:1 at rest; tested reduced-alpha fills remain at least 4.69:1. Light-mode labels stay white. Mac press feedback no longer darkens the whole control |
| Android offline status labels are faded | Old secondary at 50% on base: 2.43:1 | Names/status labels remain opaque; artwork can still fade and the status text identifies offline state |
| Mac device tooltips dim metadata again | Secondary color multiplied by 72% | Removed the extra text opacity |
| Mac sidebar hover becomes excessively bright | White at 40% overlays dark surface | Dark hover uses 6%, preserving text contrast; light behavior retained |
| Mac search affordance/color badge uses dark fixed ink | Fixed gray foregrounds | Semantic secondary foreground |
| Mac color preview uses a fixed pale card and white text on arbitrary colors | White hex label can disappear on white/yellow swatches | Semantic card/metadata surfaces; white hex label has a 75% black backing that remains readable even over white |
| Android status/navigation icons always assume light mode | Dark icons and white navigation background | Icons follow the resolved app theme; transparent system-bar backgrounds |
| Android camera chrome must work independently of app theme | Inherited light-window assumptions | Scanner requests light system-bar icons for its dark camera chrome |
| Android launch screen flashes white in system dark mode | Fixed white launch background, including Android 12+ | Night-qualified launch background `#101113` |
| Android widget ready-state dot is too dark | Purple `#6740BF` on `#1C1C1E`: 2.48:1 | Light purple `#A59DFF`: 7.18:1 |
| QR loading indicator uses light accent on white | Dark-mode foreground accent on QR's white surface | Android loading indicator uses deep purple, retaining intentional black/white QR codes |
| Focus/outline roles need a stronger signal | Mac translucent white focus; M3 translucent outline | Mac focus uses adaptive accent; Android dark M3 outline uses opaque readable gray |

The shared light tertiary token was also made readable (`#626B79`) because it serves real metadata/placeholder content and the regression test covers both palettes. Other light-mode design issues are outside this dark-mode audit.

## Screen and use-case coverage

“Reviewed” below means color declarations and state composition were inspected in source, not that the flow was executed on a device.

| Surface / use case | Mac | Android |
|---|---|---|
| Launch, create/join landing | Reviewed; adaptive splash background/text | Reviewed; adaptive landing and OS night launch background |
| Create space / name entry / refresh / validation | Reviewed; input fill, labels, focus and back affordance corrected | Reviewed; existing semantic fields inherit shared text fixes |
| Show QR / code / expiration / refresh | Reviewed; digits and surrounding UI adaptive, QR stays white | Reviewed; code panels and QR loading indicator corrected |
| Enter code / verifying / invalid code | Reviewed; semantic inputs/errors | Reviewed; digit fills, colors, error label and remaining-digit dots corrected |
| Camera scan / camera entry | No built-in Mac camera flow | Reviewed; entry card and scanner chrome corrected; camera feed requires runtime check |
| Success / empty / first connection states | Reviewed; shared colors | Reviewed; shared colors |
| Home history / search / filters / no results | Reviewed; tokens, search affordance | Reviewed; tokens and placeholders |
| Saved items | Reviewed; same Mac workspace/list components | No separate saved tab in current Android navigation |
| Text / URL / code / image / file / color content | Reviewed; shared text, color card and swatch-label correction | Reviewed; shared text, previews and content-specific surfaces |
| Download / copy feedback / file drop confirmation | Reviewed; shared and semantic colors | Reviewed; shared colors and copy feedback pair |
| Menu-bar popover / empty/loading / actions | Reviewed; shared palette improvements | Not applicable |
| Device list / online / offline / diagnostics / tooltips | Reviewed; tooltip opacity corrected | Reviewed; offline labels corrected |
| Add/remove device / pairing sheets | Reviewed; shared and onboarding fixes | Reviewed; shared and onboarding fixes |
| Settings / appearance / sync mode / retention / privacy / updates | Reviewed; shared text and selected surfaces | Reviewed; shared text and Material roles |
| Destructive dialogs / cancel / press states | Reviewed; readable destructive label and press feedback | Reviewed; readable destructive label in normal and pressed state |
| Widget: no devices / synced / pending / ready to send | Not applicable | Reviewed; fixed dark widget, accent dot corrected; neutral/action labels retain readable contrast |
| Share target / clipboard-send activity | Platform/file UI remains native | Share flow has no custom Compose screen; generated image white backing is content, not app chrome |
| Legacy auth/debug screens | Not a current navigation path | Source files are empty compatibility stubs, not active screens |

Original file artwork, arbitrary clipboard colors, image/PDF content and QR imagery are not recolored as application UI. Status text and filenames provide context alongside those assets.

## Verification

- `python3 scripts/check-dark-contrast.py`: **76 pairs pass**. Reads Mac/Android palette definitions and checks readable text on base/elevated/floating/selected/active surfaces, semantic foregrounds, destructive labels, pairing fills, widget dot, QR loading and worst-case swatch-label backing.
- Android `:app:testDebugUnitTest :app:assembleDebug`: **build successful; 71 tests, zero failures/errors/skips**. Contrast tests now include tertiary text, composited interactive states, destructive press colors and the dark Material outline.
- macOS Debug `xcodebuild`: **build successful**, signing disabled for local compilation. Existing asset warnings remain.
- `git diff --check`: passes.

Commands:

```sh
python3 scripts/check-dark-contrast.py
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' android/gradlew -p android :app:testDebugUnitTest :app:assembleDebug
xcodebuild -project mac/Airclip.xcodeproj -scheme Airclip -configuration Debug -destination 'platform=macOS' -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build
```

## Remaining rendered checks before release

1. Exercise all matrix flows with the app forced to Dark, then System, and change the system appearance while open. Android launch resources follow **system** appearance before Compose loads the saved app preference; a differing saved preference can still transition at launch.
2. Inspect the Mac popover/material surfaces over bright and dark wallpapers, with Reduce Transparency and Increase Contrast. Opaque-token ratios do not establish contrast for every material, wallpaper, animation frame or OS-rendered control.
3. On Android, verify gesture and three-button navigation, camera permission states, keyboard/code entry, QR scanning, and launcher widget states on a device. There was no connected device for this pass, and the configured emulator could not start because its initial system image is unavailable.
4. Verify keyboard focus on Mac, VoiceOver/TalkBack, larger text sizes, truncation and full pairing/sync/download/error flows. These are not covered by color arithmetic or successful compilation.
5. Check native Quick Look, PDF/media previews, OS permission dialogs and external share/open surfaces in dark mode; their rendering is partly controlled by the OS and content.

No claim of full WCAG conformance or complete visual regression coverage is made by this report.
