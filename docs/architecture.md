# AirClip Architecture

## Overview

AirClip syncs clipboard content directly between paired devices over the local network. No cloud server is in the clipboard delivery path.

```
Mac app                              Android app
  ├─ Clipboard monitor                 ├─ Foreground sync service
  ├─ Sensitive content policy          ├─ Sensitive content policy
  ├─ NaCl sealed-box encryption        ├─ NaCl sealed-box encryption
  ├─ Bonjour advertise/browse          ├─ Android NSD advertise/discover
  └─ LAN WebSocket peer ◄────────────► └─ LAN WebSocket peer
        TCP 7878 · _airclip._tcp
```

## Components

### macOS App (`mac/`)
- Swift + SwiftUI menu bar app
- `ClipboardMonitor` — watches system clipboard
- `SyncEngine` — applies sync mode and sensitive policy, drives sends
- `LanServer` / `LanBrowser` / `PeerManager` — LAN discovery and WebSocket peers
- `LocalHistoryStore` — SwiftData-backed local history
- `PairingSession` — QR/code pairing flow

### Android App (`android/`)
- Kotlin + Jetpack Compose
- `SyncService` — foreground service, keeps LAN runtime alive
- `SyncEngine` — same role as Mac: policy gating, send coordination
- `LanServer` / `LanBrowser` / `PeerManager` — NSD discovery and WebSocket peers
- `ClipHistoryStore` — local history with full-text storage
- `AirClipCaptureActivity` / `AirClipWidget` — manual send entry points

### Backend (`backend/`)
Legacy. Not in the active clipboard path. Contains FastAPI account/device bootstrap code that may be reactivated later as optional infrastructure. Do not treat it as authoritative for current behavior.

## Device Identity

Each device generates locally:
- `device_id` — unique per device
- `airclip_id` — shared across all paired devices in a group
- NaCl keypair — public key shared during pairing, private key never leaves device

## Pairing

1. User opens pairing on both devices
2. QR code or 8-digit code carries device identity metadata
3. Each device stores the peer's `device_id`, `device_name`, `platform`, and public key
4. No server involved

## LAN Connection Flow

1. Devices advertise `_airclip._tcp` on local network
2. Peer discovery via Bonjour (Mac) or NSD (Android)
3. WebSocket connection opened on TCP `7878`
4. Auth handshake — peer rejected if `airclip_id` or `device_id` not in local registry
5. On auth success: recent history pushed as backfill
6. Heartbeat every 15s to maintain last-seen presence

## Clipboard Sync Flow

1. Clipboard change detected
2. Sensitive content policy applied (Block / Ask / Allow)
3. Payload serialized to JSON `{ kindRaw, text, imageDataBase64 }`
4. Encrypted with recipient's public key (NaCl sealed box)
5. Sent as `{ type: "clip", ciphertext, nonce }` over authenticated WebSocket
6. Receiver decrypts, deduplicates, stores in history, writes to system clipboard

## History Backfill

On peer authentication, each side pushes up to 20 recent history items as `history_clip` messages. Receiver merges into local history only — never writes to system clipboard. Deduplicates by message ID or source/content/timestamp window.

## Loop Prevention

- Recent content hashes tracked per session
- Suppression recorded before tap-to-copy writes
- Remote-update suppression before live inbound clipboard writes
- Backfill never triggers clipboard writes

## Security Model

See [SECURITY.md](../SECURITY.md).

## Protocol Details

See [protocol.md](protocol.md).
