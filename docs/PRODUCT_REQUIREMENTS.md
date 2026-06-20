# AirClip Product Requirements and Roadmap

Created: 2026-06-08

## 1. Product Thesis

AirClip is a private clipboard handoff layer for people who work across multiple devices.

The product should make this feel true:

> Copy on one device. Paste on another. No messages to yourself.

The strongest version of AirClip is not just clipboard history and not just background sync. It is a quiet, trusted utility that lets a user move small clipboard content between Mac, Windows, Android, and iOS with control, speed, and confidence.

## 2. Target User

Primary user:

- Owns and actively uses multiple devices.
- Common combinations: Mac + Android, Windows + Android, Mac + iPhone, Windows + iPhone, Mac + Windows + Android.
- Frequently moves small text between devices: links, OTP codes, prompts, addresses, phone numbers, notes, snippets, commands, and short messages.
- Does not want to send text to themself through WhatsApp, Slack, email, Notes, Google Keep, or AirDrop.
- Cares about privacy because clipboard content is intimate and often sensitive.

## 3. User Perspective

### What users will love

- Copying text on one device and seeing it instantly available on another.
- A clean history that rescues something they copied earlier.
- Tap-to-copy from history.
- Pairing a new device in under 20 seconds.
- Clear device presence: which devices are nearby and ready.
- Manual send when they want control.
- Automatic sync when they trust the context.
- Sensitive content being blocked or requiring confirmation.
- Local network sync because it feels more private than cloud relay.

### What users will hate

- The app silently syncing everything with no visible guardrails.
- Passwords, API keys, bank data, private messages, or tokens being synced by default.
- Setup friction or unclear pairing.
- Sync that works sometimes but not reliably.
- Duplicate clipboard loops.
- No explanation when iOS or Android limitations make behavior different from desktop.
- No way to pause, revoke, delete, clear, or recover control.
- History that becomes noisy or permanent without consent.

### What users will not care about

- Redis, WebSockets, sequence numbers, protocol details, or crypto implementation names.
- Whether the architecture is clever.
- Engineering terms like relay, mDNS, NWBrowser, NsdManager, or sealed boxes.

Users care about the visible promises:

- Can the server read my clipboard?
- Can I stop sync?
- Can I choose where this goes?
- Can I delete it?
- Can I trust this at work?

## 4. Product Principles

1. Privacy first, but visible.
   Encryption is not enough. The UI must show control and make sensitive behavior obvious.

2. Automatic until risky.
   Auto-sync is valuable for normal text, links, and snippets. Risky-looking content should be blocked or confirmed.

3. Manual send must exist.
   Users need a deliberate action for moments where automatic sync feels too broad.

4. Platform honesty.
   macOS and Windows can monitor the clipboard. Android and iOS have restrictions. The product should design around those limitations instead of hiding them.

5. Fast pairing matters.
   Pairing should be QR/code based, local, and understandable.

6. Local-first is a differentiator.
   LAN sync should be the default trust story. Cloud relay, if added later, should be optional and explicit.

## 5. Current State Inventory

This inventory is based on the current repository as of 2026-06-08. Some older docs describe a cloud relay MVP, but the current Mac and Android source includes LAN sync and pairing code.

### Exists now

| Area | Current status |
|---|---|
| macOS app | Native Swift menu bar / window app exists. |
| macOS clipboard monitoring | Exists via `ClipboardMonitor`. |
| macOS local history | Exists via SwiftData `LocalHistoryStore`; stores text, kind, optional image data, source device, local/remote, saved flag. |
| macOS LAN sync | Exists via `LanServer`, `LanBrowser`, `PeerManager`, `PeerConnection`, and `SyncEngine`. |
| macOS pairing | Exists via AirClip identity, pairing session, code exchange, and paired device list. |
| macOS history retention | Partially exists; settings write a retention selection and prune old history. |
| macOS saved items | Partially exists at data model level with `isSaved`; product behavior needs validation. |
| Android app | Kotlin app exists under `android/app/src/main/java/com/airclip/airclip`. |
| Android LAN sync | Exists via `LanServer`, `LanBrowser`, `PeerManager`, and `SyncEngine`. |
| Android foreground/service path | Exists via `SyncService`; needs validation. |
| Android widget | Exists with `No devices`, `Synced`, `Pending`, and `Ready to send` states. |
| Android history | Exists via `ClipHistoryStore`; implementation details need validation. |
| Android manual send | Exists through widget launching `ClipboardSendActivity`. |
| Backend auth/account/device services | Exists, but current source must be reconciled with LAN-only direction. |
| E2E encryption intent | Documented and implemented in crypto layers, but cryptographic correctness should be validated with repeatable tests. |

### Needs validation

| Area | Validation question |
|---|---|
| Mac -> Android sync | Does a copied text item on Mac arrive on Android over LAN within target latency? |
| Android -> Mac sync | Does widget/manual send reliably read Android clipboard and deliver to Mac? |
| Pairing | Can a fresh device join with QR/code flow in under 20 seconds? |
| Peer discovery | Does discovery work across normal home Wi-Fi, hotspot, and blocked-mDNS networks? |
| History merge | Are duplicates suppressed across local, remote, and history backfill paths? |
| Tap-to-copy | Does tapping an item avoid echo loops and unwanted re-broadcast? |
| Sensitive content | Complete on Android and macOS; paired physical-device validation passed on 2026-06-14. |
| Pause controls | Currently unclear; must be added or verified. |
| Device removal | Existing UI/source references exist; end-to-end behavior needs validation. |
| iOS | Source exists but README says project setup is manual. Treat as future until validated. |
| Windows | Not implemented. |

### Docs that need reconciliation

Older docs still describe backend relay, Redis history, sequence ordering, and server catch-up. Current code appears to favor LAN direct sync. Before adding major features, update the architecture docs to choose one source of truth:

- Preferred product direction: LAN-first sync.
- Backend role: account/device bootstrap only, unless cloud relay is intentionally reintroduced later as an optional feature.

## 6. MVP Product Definition

The MVP should prove:

> A user can privately pair a Mac and Android phone, copy text on either device, send or receive it reliably over LAN, and control history/sync behavior without fear.

### MVP platforms

- macOS: monitor, send, receive, history, settings, pairing.
- Android: receive, manual send, widget, history, pairing, foreground service.

### MVP content types

- Plain text.
- URLs as text with URL-specific display affordances.
- Images are optional only if already stable; do not let image support delay trusted text sync.

### MVP non-goals

- Windows.
- iOS production support.
- Cloud relay.
- Large files.
- Universal rich clipboard support.
- Team/admin product.

## 7. Feature Roadmap

Implementation progress is tracked step by step in `ROADMAP_STATUS.md`.

### Phase 0: Source-of-truth audit

Goal: confirm what currently works before adding features.

Deliverables:

- Update `docs/architecture.md` to reflect LAN-first architecture.
- Update `docs/mvp-scope.md` to match the current Mac + Android LAN direction.
- Create a manual test checklist for Mac + Android.
- Create a known-gaps list from actual build/test results.

Acceptance criteria:

- We can state which flows work, which fail, and where the failure comes from.
- No major roadmap item is based only on stale docs.

Manual tests:

- Build Mac app.
- Build Android app.
- Pair Mac and Android on same Wi-Fi.
- Copy Mac -> receive Android.
- Widget send Android -> receive Mac.
- Disconnect/reconnect Wi-Fi and verify recovery behavior.
- Clear history and verify local storage is empty.

### Phase 1: Trust and control basics

Goal: make automatic clipboard sync feel safe.

Features:

- Global sync mode:
  - Auto-sync normal text.
  - Manual send only.
  - Pause for 15 minutes.
  - Pause for 1 hour.
  - Pause until resumed.
- Visible sync status:
  - Ready.
  - Paused.
  - No devices nearby.
  - Syncing.
  - Last synced.
- Clear history.
- Delete individual history item.
- Device revoke/remove with confirmation.
- Encryption always-on messaging; no encryption toggle.

Acceptance criteria:

- Paused mode stops inbound and outbound LAN activity, including discovery, advertisement, listeners, and peers.
- Manual send works while auto-sync is off.
- Device removal disconnects the peer and prevents future sync until re-paired.
- Clear/delete actions persist after app restart.

### Phase 2: Sensitive-content protection

Goal: prevent the product from feeling creepy or dangerous.

Features:

- Sensitive classifier for clipboard text:
  - Password-like strings.
  - API keys/tokens.
  - Private keys.
  - Seed phrases.
  - Credit card-like numbers.
  - One-time codes, with configurable behavior.
- Default policy:
  - Block obvious secrets from auto-sync.
  - Show local notice: "Sensitive clipboard item blocked."
  - Allow manual override/send if user explicitly chooses.
- Per-rule settings:
  - Always block.
  - Ask before sending.
  - Allow.

Acceptance criteria:

- Known test secrets are not auto-synced.
- Normal URLs and text still sync.
- Blocked items do not appear on remote devices.
- Blocked items are not logged in plaintext.

### Phase 3: Better history

Goal: make AirClip useful even when sync is not the immediate need.

Features:

- Search history.
- Saved/pinned clips.
- Source device label.
- Relative time.
- Type filters: text, links, images if supported.
- Retention choices: 7 days, 30 days, 90 days, forever.
- Max item cap with saved items protected from eviction.

Acceptance criteria:

- Search returns local history quickly.
- Saved items are not deleted by normal retention pruning.
- Retention settings survive restart and apply consistently.
- UI remains readable with long text, URLs, and empty states.

### Phase 4: Reliability and recovery

Goal: make LAN sync predictable enough for daily use.

Features:

- Peer presence heartbeat.
- Clear pairing state and last seen time.
- Connection diagnostics:
  - Same Wi-Fi required.
  - Local network permission missing.
  - Peer unavailable.
  - Clipboard permission issue.
- Local history backfill when peers reconnect.
- Duplicate suppression across send, receive, tap-to-copy, and history backfill.

Acceptance criteria:

- Reconnecting devices exchange recent history without overwriting the active clipboard unexpectedly.
- Duplicate clipboard loops do not occur.
- UI shows actionable status when discovery fails.
- A user can recover from app restart, device sleep, and Wi-Fi reconnect.

### Phase 5: Platform expansion

Goal: expand only after Mac + Android is trusted.

Order:

1. Windows desktop sender/receiver.
2. iOS manual receive/send model.
3. Optional cloud relay for remote networks.

Windows requirements:

- Clipboard monitor.
- Local history.
- LAN discovery and peer protocol compatibility.
- Manual send/pause/sensitive protection parity.

iOS requirements:

- Honest UX around clipboard limitations.
- Manual send via share sheet/widget/app intent.
- Receive flow if platform behavior is reliable.
- Local history and saved items.

Cloud relay requirements, if added:

- Explicit opt-in.
- Same sensitive-content policy.
- E2E encryption.
- No permanent plaintext storage.
- Clear remote-network status.

## 8. Validation Plan

### Build validation

- Mac builds from `mac/AirClip.xcodeproj`.
- Android builds from Gradle.
- Backend tests pass if backend remains part of bootstrap.

### Manual product validation

Run these as a standing checklist after each feature:

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

### Design validation

For each visible feature, capture screenshots for:

- Empty state.
- One item.
- Many items.
- Long text.
- Long URL.
- No devices nearby.
- Paused mode.
- Sensitive item blocked.
- Pairing flow.
- Error state.

Design issues should be traced to the exact view, token, frame, layout modifier, or platform constraint before editing.

## 9. Success Metrics

MVP success:

- Pairing completes in under 20 seconds in normal conditions.
- Mac -> Android text sync usually completes in under 2 seconds on LAN.
- Android -> Mac manual send usually completes in under 2 seconds on LAN.
- No plaintext clipboard content is logged.
- Sensitive test samples are blocked from auto-sync.
- Users can pause sync, clear history, and remove a device without confusion.

Product quality bar:

- A user understands what is synced.
- A user understands which devices can receive it.
- A user can stop syncing immediately.
- A user trusts the app after copying something sensitive.

## 10. Immediate Next Steps

1. Implement Device Management Reliability now that Sensitive Clipboard Protection passed paired validation on 2026-06-14.
2. Fix any blocking Mac + Android build issues.
3. Validate current pairing and LAN sync manually.
4. Implement global sync modes.
5. Implement sensitive-content blocking.
6. Improve history with search, saved items, delete, and retention.
7. Only then expand platforms.
