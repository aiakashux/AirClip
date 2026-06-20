# AirClip Roadmap Status

Updated: 2026-06-19

This is the current implementation tracker for the LAN-first Mac + Android AirClip MVP.

The current product direction is:

> Pair a Mac and Android phone, sync clipboard content privately over LAN, and give the user clear control over what is sent, stored, paused, or removed.

Older backend-relay rebuild planning has been removed from the project. Use this document, `PRODUCT_REQUIREMENTS.md`, and `VALIDATION_CHECKLIST.md` as the active planning set.

## Current Progress

Roadmap progress: `3/5` major feature groups complete.

Current implementation focus: physical-device validation for device reliability, history polish, and recovery behavior.

## Step 1: Source-of-Truth Audit

Status: Complete for the LAN-first MVP source of truth.

What was done:

1. Confirmed the current product direction is LAN-first Mac + Android sync.
2. Confirmed older backend relay, Redis history, sequence ordering, and cloud catch-up assumptions are stale for the current MVP.
3. Created current product requirements in `PRODUCT_REQUIREMENTS.md`.
4. Created the validation tracker in `VALIDATION_CHECKLIST.md`.
5. Validated that the Mac app builds and launches.
6. Validated that the Android debug APK builds, installs, launches, starts the foreground service, advertises `_airclip._tcp`, and listens on TCP `7878`.
7. Confirmed the old backend failures were stale Redis relay and presence expectations.
8. Removed the old `docs/PLAN.md` file from the project.
9. Rewrote `README.md` around native Mac + Android LAN-first sync.
10. Rewrote `docs/architecture.md` around local pairing, LAN discovery, peer auth, encrypted packets, local history, and recovery backfill.
11. Rewrote `docs/mvp-scope.md` around the current LAN-first MVP scope and non-goals.
12. Rewrote `docs/protocol.md` around the active LAN WebSocket peer protocol.
13. Rewrote `DEV_SETUP.md` around current macOS and Android build/run/test workflows.
14. Rewrote `docs/security.md` around the current LAN-first security model.
15. Updated `mac/README.md` and `backend/README.md` so they no longer present the old relay model as active.
16. Rewrote stale backend Redis presence and relay WebSocket tests around the current minimal SQLite account/device bootstrap and heartbeat WebSocket behavior.
17. Re-ran backend tests successfully: `12 passed`.

Still waiting:

1. Nothing for Step 1. Backend auth/account/device bootstrap is documented as legacy or future optional infrastructure, not active clipboard transport.

## Step 2: Global Sync Modes

Status: Complete.

What was done:

1. Added global sync behavior for Auto, Manual, and Paused modes.
2. Verified Auto mode supports bidirectional transfer.
3. Verified Manual mode blocks automatic capture while still allowing explicit send.
4. Verified Paused mode tears down LAN runtime state.
5. Verified Paused mode stops Android service, notification, listener, discovery, advertisement, and peers.
6. Verified Paused mode stops Mac listener, Bonjour advertisement, browser, and peers.
7. Verified restart persistence for Paused and Manual modes.
8. Verified echo suppression and duplicate-free pause/resume cycles.
9. Verified paired Mac + OnePlus 6 transfer behavior on the same Wi-Fi.

Still waiting:

1. Keep regression-testing sync modes after device-management and recovery changes.
2. Continue validating UI clarity for each sync state.

## Step 3: Sensitive Clipboard Protection

Status: Complete.

What was done:

1. Added local sensitive-content classifiers on Android and macOS.
2. Covered password-like strings, API keys/tokens, private keys, recovery phrases, payment cards, and one-time codes.
3. Added per-category policy controls: Block, Ask, and Allow.
4. Made Ask block automatic transfer and require explicit confirmation for manual send.
5. Made Block reject both automatic and explicit sends.
6. Made Allow permit automatic and explicit sends for that category.
7. Applied policy checks to Android main-app send, Android widget send, macOS automatic capture, macOS main-window send, and macOS menu-bar send.
8. Added transport-level fallback guards for sensitive sends that bypass normal UI paths.
9. Validated Android policy tests, Android debug build, macOS policy checks, and macOS debug build.
10. Validated paired physical-device behavior for safe text, sensitive blocked samples, Ask cancel/confirm, Block persistence, Allow persistence, Auto suppression, and widget sends.
11. Confirmed logs contain only lengths, hashes, category metadata, and no validation secret plaintext.

Still waiting:

1. Keep regression-testing sensitive policy behavior after new send paths, history backfill, or cloud relay work.
2. Improve user-facing blocked/confirmation copy if design review finds unclear states.

## Step 4: Device Management Reliability

Status: In progress.

What was done:

1. Paired Mac and Android identities were validated without destructive reset.
2. Pairing persistence across restart was validated for current identities.
3. Runtime validation proved peers can connect and transfer over LAN after pairing.
4. A transient Android `Address already in use` listener warning was identified after a forced runtime restart.
5. Device removal now disconnects that device's active peer connection on macOS.
6. Device removal now disconnects that device's active peer connection on Android.
7. LAN auth now rejects removed devices instead of trusting only the shared `airclip_id`.
8. Android peer teardown now ignores stale socket-close events when a newer connection for the same device is active.
9. macOS and Android now exchange app-level heartbeat messages every 15 seconds while connected.
10. Heartbeat and heartbeat acknowledgements refresh each paired device's `lastSeenMs`.
11. Device UI now shows clearer online/last-seen presence text.
12. Android LAN server startup is now idempotent and no longer stops/rebinds an already running server.
13. macOS Devices now shows a same-Wi-Fi hint when paired devices exist but no remote peers are connected.
14. Android Devices now distinguishes Paused, unpaired, and paired-but-no-peer diagnostic states.
15. macOS Devices now distinguishes Paused from no-nearby-device diagnostics.
16. Android now surfaces LAN listener, discovery, and advertisement startup failures as device-screen diagnostics instead of log-only warnings.
17. macOS now surfaces LAN listener and Bonjour discovery failures in the Devices network hub.

Still waiting:

1. Validate fresh pairing from reset state on both devices.
2. Validate QR/code pairing completes under the target time.
3. Validate heartbeat-driven last-seen updates on physical Mac + Android devices.
4. Validate remove/revoke device behavior end to end on physical Mac + Android devices.
5. Validate removed devices cannot reconnect until re-paired.
6. Validate re-pairing after removal.
7. Validate that the Android listener `Address already in use` warning no longer appears during forced restart cycles.
8. Validate deeper diagnostics for OS-level local-network permission and clipboard permission issues.

## Step 5: Better History

Status: In progress.

What was done:

1. Mac local history exists.
2. Android local history exists.
3. Saved item data paths exist.
4. Delete item paths exist.
5. Retention settings exist at least partially.
6. Mac to Android image sync was validated on a physical OnePlus 6, including byte-for-byte PNG preservation.
7. Saved clips are protected from normal retention pruning on macOS.
8. Saved clips are protected from Android TTL cleanup and item-cap pruning.
9. macOS history search now matches clip text, type, and source device label.
10. Android history search now matches clip preview, type, and source device label.
11. macOS history now has compact type filters for All, Text, Links, and Images.
12. Android history now has compact type filters for All, Text, Links, and Images.

Still waiting:

1. Validate history search on physical Mac + Android devices.
2. Validate saved/pinned clip behavior across restart.
3. Validate saved clips survive normal retention pruning and item-cap eviction.
4. Validate source device labels are clear on physical devices.
5. Validate relative time is clear on physical devices.
6. Validate type filters for text, links, and images.
7. Validate retention choices: 7 days, 30 days, 90 days, and forever.
8. Validate clear-history behavior persists after restart.
9. Validate delete-one-item behavior persists after restart.
10. Validate long text, long URLs, empty history, many items, and image previews do not break layout.

## Step 6: Reliability and Recovery

Status: In progress.

What was done:

1. Basic LAN transfer validation passed in both directions.
2. Restart persistence for sync mode passed.
3. Duplicate suppression passed for validated pause/resume and echo cases.
4. macOS now receives `history_clip` backfill messages and merges them into local history without writing to the system clipboard.
5. macOS history backfill merge deduplicates by message ID when possible and by source/content/timestamp window otherwise.
6. Android now pushes up to 20 recent history records to a peer after authentication.
7. Android backfill uses the same clipboard packet JSON shape that macOS already decodes.
8. Android backfill continues to merge into history only and does not write to the active system clipboard.
9. Android history now stores full clip text separately from the short UI preview.
10. Android history copy, search, preview, echo suppression, and backfill now use full clip text when available.
11. Android deduplication upgrades older preview-only duplicates when a later full-text history copy arrives.
12. Android discovery/listener/advertisement failures now feed an explicit runtime diagnostic state for recovery UX.
13. macOS listener/discovery failures now feed an explicit runtime diagnostic state for recovery UX.
14. Android history tap-to-copy now records suppression before writing to the clipboard.
15. Android history tap-to-copy now suppresses image echoes by image payload hash instead of text label only.
16. macOS history tap-to-copy now records the packet hash as well as suppressing the immediate clipboard change.

Still waiting:

1. Validate local history backfill when peers reconnect on physical Mac + Android devices.
2. Validate reconnect backfill does not overwrite the active clipboard unexpectedly.
3. Validate recovery after app restart.
4. Validate recovery after device sleep.
5. Validate recovery after Wi-Fi disconnect/reconnect.
6. Validate blocked-mDNS or hotspot network behavior.
7. Validate duplicate suppression across send, receive, tap-to-copy, and history backfill on physical devices.
8. Validate discovery failure states are visible and actionable on physical Mac + Android devices.

## Step 7: Platform Expansion

Status: Waiting until Mac + Android is trusted.

What was done:

1. iOS source exists but is treated as future/unvalidated.
2. Windows is not implemented.
3. Cloud relay is intentionally out of the MVP.

Still waiting:

1. Build Windows sender/receiver after Mac + Android quality is stable.
2. Add Windows clipboard monitoring, local history, LAN discovery, peer protocol compatibility, manual send, pause, and sensitive-protection parity.
3. Revisit iOS with honest clipboard-limitation UX.
4. Explore iOS manual send through share sheet, widget, or app intent.
5. Consider optional cloud relay only after LAN-first sync is reliable.
6. If cloud relay returns, make it explicit opt-in, E2E encrypted, sensitive-policy aware, and clear about remote-network status.

## Standing Validation Checklist

Run after each feature or reliability change:

1. Fresh install or reset both devices.
2. Pair devices.
3. Verify status shows connected devices.
4. Copy normal text on Mac.
5. Confirm Android receives it and can paste it.
6. Send from Android widget.
7. Confirm Mac receives it and can paste it.
8. Tap history item on each platform.
9. Verify no echo loop.
10. Pause sync and verify no outbound auto-sync.
11. Resume sync and verify delivery.
12. Delete one history item and restart app.
13. Clear all history and restart app.
14. Try sensitive samples and verify blocking.
15. Remove paired device and verify sync stops.
