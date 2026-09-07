# AirClip Mac + Android Audit

Date: 2026-09-06  
Scope: current working tree, installed Mac app, feature parity, Mac UI, and reported reliability issues.

## Executive summary

The first release priority should be reliability, not more features. The Mac app can enter a stale LAN state after sleep, network changes, or a graceful peer disconnect, and much of its networking, history backfill, image conversion, encryption, and persistence runs on the main actor. That combination matches the reported “stops syncing, then the UI/history freezes until force quit” behavior.

The product is also not at feature parity. The largest gaps are Mac manual send, visible Mac filters, delete undo, clear-history access, matching retention choices, and real keyboard shortcuts. The design mismatch is caused by several palettes inside the Mac app plus a separate Android palette—not by one bad color value.

## Priority findings

### P0 — Mac runtime does not recover reliably

Evidence:

- `PeerConnection` removes peers for `.failed` and `.cancelled`, but not `.waiting` (`mac/AirClip/Core/PeerConnection.swift:37`). A waiting connection can remain registered.
- `PeerManager.connectIfNeeded` refuses a new connection while that stale peer or pending hint remains (`mac/AirClip/Core/PeerManager.swift:40`).
- `LanBrowser` and `LanServer` report failure but retain their non-nil browser/listener. Later `start()` calls therefore return without restarting (`mac/AirClip/Core/LanBrowser.swift:17`, `mac/AirClip/Core/LanServer.swift:51`).
- There is no wake, network-path, or application-reactivation recovery hook in the Mac target.
- `receiveNext()` ignores completion state and unconditionally starts another receive when no error is returned (`mac/AirClip/Core/PeerConnection.swift:50`). A graceful close needs to terminate the receive loop.
- Network callbacks, encryption/decryption, SwiftData fetches, history backfill, and image normalization are main-actor work. Reconnecting can push 20 image-heavy items while blocking UI (`mac/AirClip/Core/PeerConnection.swift:349`, `mac/AirClip/Core/LocalHistoryStore.swift:145`, `mac/AirClip/Views/ClipTypeDetector.swift:24`).
- Send failures are ignored, so stale peers look healthy until something else removes them (`mac/AirClip/Core/PeerConnection.swift:416`).

Recommended fix:

1. Make failed/waiting browser and listener states tear down and retry with a small capped backoff.
2. Remove waiting/closed peers and pending hints deterministically; stop the receive loop on completion.
3. Reconnect on Mac wake and network-path recovery.
4. Move crypto, image normalization, and history backfill off the main actor; publish only UI/store mutations on the main actor.
5. Add one lifecycle regression check covering connected → network lost → network restored → authenticated again.

### P0 — Mac clipboard capture can silently stop

The Mac clipboard timer is started only when pairing or sync-mode policy is applied (`mac/AirClip/Core/SyncModeStore.swift:25`). There is no health check or wake/reactivation restart. Local clips are inserted only after this timer captures them, so a dead/stalled timer explains why new Mac copies also disappear from local history.

Recommended fix: make clipboard monitoring self-healing on wake/reactivation and use a run-loop mode that remains appropriate for a menu-bar utility. Keep the existing change-count guard; do not add a second monitor.

### P1 — Copy confirmation is intentionally three seconds long

`copyCloseDelay` is `3.00` seconds (`mac/AirClip/Views/PopoverView.swift:21`). The cards disappear after 0.10 seconds, leaving the confirmation floating alone. This is the reported lingering tooltip.

Recommended behavior: show an inline check state for roughly 500–800 ms and close the panel around 700 ms, or close immediately and rely on the check state when Reduce Motion is enabled. Remove the spring and the heavy toast shadow.

### P1 — Duplicate image history is visible

The installed Mac Home screen showed the same Android screenshot repeatedly. Current code compares full base64 image strings by repeatedly rebuilding `ClipboardPacket` values across the entire history. This is expensive and makes deduplication dependent on identical encoding.

Recommended fix: store one content hash per item and deduplicate by hash. Do not compare full base64 payloads in UI/store hot paths.

### P1 — Android tests are currently red

Mac builds successfully. Android compiles, but 2 of 39 unit tests fail:

- `ClipboardWirePayloadTest.preserves ordinary json clipboard text`
- `SyncModeTest.missing or invalid stored value defaults to manual only`

These appear to be behavior/spec drift in the current working tree and should be resolved before parity work.

## Head-to-head feature audit

| Feature | Android | Mac | Gap / decision |
|---|---|---|---|
| Create/join network | QR scan, show QR, numeric code | Show QR and numeric code | Platform-appropriate parity |
| Add/remove device | Yes | Yes | Keep; simplify Mac device presentation |
| Online/last-seen state | List + diagnostics | Decorative orbit + terse status | Mac should use a scannable list and explicit reconnect/error action |
| Auto sync | Yes | Yes | Reliability work required on Mac |
| Manual sync mode | Yes, visible send action | Missing; stored legacy value is converted to Auto | Major Mac gap |
| Paused mode | Yes | Yes | Parity |
| Text/URL/image/color/email | Yes | Yes | Protocol parity; image reliability needs work |
| Local history | Up to 500 | Up to 100 | Choose one documented limit |
| Search | Yes | Yes | Parity |
| Type filters | Visible: Saved/Text/Link/Image/Color | Code exists but is never rendered; no Color filter | Major Mac gap |
| Saved clips | Filter | Dedicated sidebar page | Equivalent outcome; Mac is stronger here |
| Preview/open link | Yes | Yes | Parity |
| Delete item | Yes, with Undo | Yes, immediate | Add Mac Undo |
| Clear all history | Missing from current screen | Missing from current screen; only legacy unused view has it | Missing on both; required by PRD |
| Retention | 1/3/7/15/30 days/limit | 7/30/90 days/forever | Align choices and semantics |
| Sensitive-content master policy | Yes | Yes | Parity |
| Per-category sensitive rules | Logic exists, not exposed | Exposed | Android UI gap |
| Share-sheet/manual entry | Android share target + widget | Menu-bar picker | Platform-specific equivalents |
| Keyboard shortcuts | Not applicable in same form | Listed in Settings, not implemented | Misleading Mac UI; wire them or remove the claims |
| Sync diagnostics | Actionable banners | Small hub text | Mac needs a visible offline/failed state and reconnect action |
| Appearance | System/light/dark | System/light/dark | Token values still differ |

## Major missing product features

Must-have before adding new scope:

1. Self-healing Mac sync after sleep, Wi-Fi changes, peer restarts, and graceful disconnects.
2. Mac Manual mode with a clear “Send clipboard” action in the menu popover and main window.
3. Visible Mac type filters, including Color, using the already-present filter state.
4. Clear History on both platforms, with saved-item behavior stated clearly.
5. Mac delete Undo and actual Mac keyboard shortcuts.
6. A single cross-platform behavior contract for defaults, history limits, retention, clip types, and sensitive rules.

Useful after stabilization:

- Per-device “last synced” and a one-click reconnect action.
- A small transfer state for large images: preparing, sending, failed, retry.
- Export/import of saved clips only if users ask for portability. It is not needed for the current MVP.

## Brand and UI audit

### Brand drift

There are currently three visual sources of truth:

1. `mac/AirClip/DesignTokens.swift`
2. private `MainWindowPalette` values in `MainWindowView.swift`
3. `AirClipTheme.kt` on Android

Violet `#5647F2` is the approved AirClip accent; coral is explicitly excluded. The repository’s older AirClip design guidance still specifies coral `#FF6363` and should be corrected when implementation starts. Within the Mac app, the main window, popover, and shared components also use different raw surface/text values. Android light mode uses pure white for the base while Mac uses a cool gray shell. This is why the products feel related but not identical.

Recommendation: align the existing semantic tokens on violet `#5647F2` across both platforms. Do not introduce another design-system layer. Remove private/raw color copies as each screen is touched.

### Mac Home

- Good: clear sidebar, useful split list/preview layout, saved clips, source device, relative time.
- Improve: render the existing filters; group every time section rather than labeling only the first item’s section; expose sync health; add Manual send; use a less empty preview layout.
- Remove: per-card gradients and shadows in the menu popover. Rows/cards should be nearly flat; only the popover container needs elevation.

### Mac menu popover

- The 3-second copy state is too long.
- Every card has a strong shadow (`PopoverView.swift:355`), producing the harsh icon/card effect described by the user.
- The popover contains many raw hex colors and gradients, so it drifts from the main window and Android.
- Five recent items is appropriate. Keep that limit.

Recommended treatment: one translucent popover surface, flat rows separated by spacing or hairlines, a subtle hover fill, and one short checkmark confirmation. No individual row shadows.

### Mac Devices

The orbit is visually distinctive but weak for scanning status, long device names, more than a few devices, keyboard navigation, and error recovery. Android’s device list is more useful.

Recommended treatment: a compact device list with icon, name, platform, online/last-seen, network, and a trailing menu. Put Add Device and Reconnect in the header. This is simpler and more accessible than maintaining the orbit layout.

### Mac Settings

- The current screen is dense but understandable.
- Uppercase section labels and custom Beary headings conflict with the Mac design guidance and native hierarchy.
- Version/build are hard-coded (`MainWindowView.swift:2571`) instead of read from the bundle.
- Shortcut rows claim behavior that is not implemented.
- Clear History is absent.
- The separate `SettingsView.swift` is legacy/unused and creates a second settings design.

Recommended treatment: keep four groups—General, Sync & Privacy, Shortcuts, About/Danger Zone. Use native controls, sentence-case labels, bundle version values, and delete the unused settings screen after confirming no callers.

### Accessibility

- Several icon-only controls rely on `.help` instead of explicit accessibility labels.
- The custom sidebar does not expose standard keyboard navigation.
- The filter buttons are 24 pt high and the clear-search target is 16 pt.
- The decorative device orbit is difficult to traverse and understand with assistive technology.
- Motion uses several springs/rotations despite the design rule favoring short ease-out response and reduced motion.

## Proposed direction represented by the concept snapshot

The generated concept keeps the current sidebar and split-view idea, but makes these changes:

- one shared violet accent;
- visible filters;
- explicit sync and encryption status;
- a Manual-mode send action;
- flat list rows and one subtle window shadow;
- calmer, labeled actions.

It is a direction mockup, not a pixel specification. The app should use native SwiftUI controls and the existing icon set rather than copying generated pixels.

## Implementation plan

### Phase 1 — Stabilize

1. Reproduce with sleep/wake, Wi-Fi off/on, Android process kill/restart, and graceful socket close.
2. Fix Mac connection teardown/retry and receive-loop completion.
3. Restore clipboard monitor on wake/reactivation.
4. Move expensive sync/image/history work off the main actor.
5. Add the smallest lifecycle and clipboard-monitor checks.
6. Fix the two failing Android tests.

Exit criterion: both directions recover without relaunch across the four lifecycle scenarios.

### Phase 2 — Close parity gaps

1. Restore Mac Manual mode and add Send Clipboard.
2. Render Mac filters and add Color.
3. Align retention options and history limit.
4. Add Clear History to both apps.
5. Add Mac delete Undo.
6. Wire Mac shortcuts; expose Android per-category sensitive rules.

Exit criterion: the feature table has no unintended platform gaps.

### Phase 3 — Visual cleanup

1. Approve the brand accent and shared semantic token values.
2. Flatten the Mac popover and shorten copy feedback.
3. Replace the device orbit with a useful device list.
4. Consolidate Mac settings and remove the unused settings implementation.
5. Add explicit accessibility labels and keyboard/focus behavior.

Exit criterion: light/dark screenshots from both apps use matching semantic colors and all Mac flows are keyboard-accessible.

### Phase 4 — Verification

Run both apps for an extended session with repeated image/text copies, sleep/wake, network loss, and peer restarts. Verify latency, duplicate rate, memory/CPU, and recovery time. Add screenshots for Home, Devices, Settings, empty, offline, error, and Manual mode.

## Helpful user input (not blocking)

- Whether the freeze usually follows Mac sleep, a Wi-Fi change, Android backgrounding, or simply idle time.
- One light-mode and one dark-mode Android screenshot from the exact build being compared.
