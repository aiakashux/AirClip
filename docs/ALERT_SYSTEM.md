# Alert system

This is the source of truth for transient in-app alerts on macOS and Android.

## Component

| Variant | Leading icon | Text colour | Right-side control |
| --- | --- | --- | --- |
| Regular | None | Primary | Close, or an action such as **Undo** |
| Success | Green check circle | Primary | Close |
| Danger | Yellow warning triangle | Yellow | Close |

All variants use the Figma alert component: a white, 24pt-radius capsule with a `#EDEDED` border, 20pt horizontal and 14pt vertical padding, 16pt medium one-line text, and a subtle two-layer shadow.

## Placement and motion

| Platform | Placement | Enter / exit | Duration |
| --- | --- | --- | --- |
| macOS | Bottom centre, 24pt above the window edge | 18pt vertical move, opacity 0–1, blur 4–0 | 220ms in / 180ms out |
| Android | Bottom centre, 16dp above bottom navigation | Rises from behind the navigation, opacity 0–1, blur 4–0 | 220ms in / 180ms out |

Alerts dismiss automatically after 2.8 seconds. Danger alerts remain for 4.5 seconds. Alerts with an action remain for 5 seconds. Tapping close dismisses immediately; tapping an action completes it and dismisses the alert.

## Current triggers

| Event | Alert | Variant | Platforms |
| --- | --- | --- | --- |
| Clip copied from the macOS list or preview | `Copied to clipboard` | Success | macOS |
| Clip saved | `Saved` | Success | macOS |
| Clip deleted | `Deleted` + **Undo** | Regular | macOS, Android |
| Manual sync blocks sensitive content | `Sensitive item wasn’t shared` | Danger | macOS, Android |

Android’s bottom-sheet copy control keeps its existing copy-to-check icon morph rather than adding a second alert.

## Empty-state guidance

These are persistent empty states, not alerts or coach marks:

| Surface | Text |
| --- | --- |
| Devices, with no other devices connected | `Your space is ready. Connect a device to start syncing.` |

Coach marks and progressive onboarding are intentionally out of scope until they are redesigned and approved.
