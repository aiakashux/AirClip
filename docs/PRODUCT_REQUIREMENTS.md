# AirClip Product Requirements

## What It Is

AirClip is a private clipboard sync utility for people who work across multiple devices.

> Copy on one device. Paste on another. No messages to yourself.

## Target User

- Uses Mac + Android daily
- Frequently moves links, OTP codes, addresses, snippets, and short text between devices
- Cares about privacy — clipboard content is often sensitive
- Does not want to send things to themselves via Slack, WhatsApp, or Notes

## Product Principles

1. **Privacy first, but visible.** Encryption alone isn't enough. The UI must make control obvious.
2. **Automatic until risky.** Auto-sync for normal text. Sensitive content gets blocked or confirmed.
3. **Manual send must exist.** Users need a deliberate action for moments where auto-sync feels too broad.
4. **Platform honesty.** macOS can monitor the clipboard. Android and iOS have restrictions. Design around that, don't hide it.
5. **Local-first is the trust story.** LAN sync is default. Cloud relay, if ever added, is explicit opt-in.

## Current Platforms

| Platform | Status |
|----------|--------|
| macOS (menu bar) | Active |
| Android | Active |
| iOS | Planned |
| Windows | Planned |

## Core Features

### Sync Modes
- **Auto** — every clipboard change syncs instantly
- **Manual** — tap/click to send only
- **Paused** — no LAN activity at all

### Sensitive Clipboard Protection
Runs locally before any content leaves the device.

| Category | Default |
|----------|---------|
| Passwords | Block |
| API keys / tokens | Block |
| Private keys | Block |
| Recovery phrases | Block |
| Payment cards | Block |
| OTP / 2FA codes | Ask |

Per-category policy: **Block**, **Ask**, or **Allow**.

### Pairing
- QR code exchange, local only
- Completes in under 20 seconds
- No account or login required

### Local History
- Newest-first
- Search, type filters (text / links / images)
- Saved/pinned clips (protected from pruning)
- Delete one item or clear all
- Retention: 7d / 30d / 90d / forever
- Source device label + relative time

### Device Management
- See which devices are paired and online
- Heartbeat-driven last-seen presence
- Remove a device → disconnects immediately, cannot reconnect until re-paired

## MVP Success Criteria

- Pairing completes in < 20 seconds
- Mac → Android text sync in < 2 seconds on LAN
- Android → Mac manual send in < 2 seconds on LAN
- No clipboard plaintext in logs
- Sensitive test samples blocked from auto-sync
- User can pause sync, clear history, and remove a device without confusion

## Non-Goals (Current MVP)

- Cloud relay as default
- Server-side clipboard history
- Windows (next phase)
- iOS production support (next phase)
- Enterprise / admin controls
- Large file sync
