# AirClip MVP Scope

Status: Current LAN-first MVP scope.

The MVP goal is to make Mac + Android clipboard sync feel reliable, private, and understandable on the same local network.

## Objective

Prove that a user can pair a Mac and Android phone, sync clipboard content privately over LAN, and control what is sent, stored, paused, or removed.

## Included Platforms

| Platform | MVP role |
| --- | --- |
| macOS | Sender, receiver, history, pairing, device management |
| Android | Sender, receiver, history, pairing, device management, widget send |

## Not Included Yet

| Platform / feature | Status |
| --- | --- |
| Windows | Future |
| iOS | Future, with clipboard-limitations UX required |
| Optional cloud relay | Future opt-in only |
| Permanent cloud history | Not in MVP |

## Core Features

### LAN Clipboard Sync

Clipboard content can move between paired Mac and Android devices over the same local network.

Target behavior:

1. Normal text syncs in both directions.
2. URLs, code-like text, emails, colors, and image packets are classified for history display.
3. Image sync remains in scope where platform capture/send paths support it.
4. Sync works without a central relay server.

### Pairing

Pairing uses local QR/code exchange. After pairing:

1. Both devices share an `airclip_id`.
2. Each device stores the other device's public key and metadata.
3. Peers are trusted only if they present the shared `airclip_id` and a locally paired `device_id`.

### Sync Modes

The MVP includes three global sync modes:

1. Auto: automatic capture plus LAN service.
2. Manual: explicit sends only, LAN service available.
3. Paused: no LAN listener, discovery, advertisement, active service, or peers.

### Sensitive Clipboard Protection

Sensitive-content protection is local and applies before sending:

1. Block prevents automatic and explicit sends.
2. Ask blocks automatic sends and requires confirmation for explicit sends.
3. Allow permits the category.

Covered categories include password-like strings, API keys/tokens, private keys, recovery phrases, payment cards, and one-time codes.

### Device Management

Users can view paired devices, see presence/last-seen information, remove paired devices, and re-pair devices.

Required behavior:

1. Removed devices disconnect immediately.
2. Removed devices cannot reconnect until re-paired.
3. Heartbeats keep last-seen information fresh while connected.
4. UI distinguishes paused, unpaired, no-nearby-peer, listener/discovery failure, and online states.

### Local History

Each platform stores local history.

Required behavior:

1. Newest-first ordering.
2. Search.
3. Saved clips.
4. Delete one item.
5. Clear all history.
6. Retention options where supported.
7. Type filters for text, links, and images.
8. Source device labels and relative time.
9. Saved clips protected from normal retention pruning.

### Recovery

The MVP should recover from ordinary LAN interruptions:

1. App restart.
2. Device sleep/wake.
3. Wi-Fi disconnect/reconnect.
4. Bonjour/NSD rediscovery.

On reconnect, peers push recent encrypted history to each other. Backfill must not overwrite the active clipboard.

## Explicit Non-Goals

1. Cross-network sync over mobile data.
2. Cloud relay as default behavior.
3. Server-side clipboard history.
4. Redis-backed sequence ordering.
5. Account-based pending device approval.
6. Background clipboard monitoring on platforms that do not permit it.
7. Enterprise admin controls.

## Completion Definition

The Mac + Android MVP is trusted when:

1. Pairing works from reset state.
2. Normal text sync works in both directions.
3. Manual and Paused modes behave predictably.
4. Sensitive policies block/ask/allow correctly.
5. Remove/re-pair behavior is reliable.
6. History survives restart and respects saved clips.
7. Recovery after restart/sleep/Wi-Fi interruption works without duplicate loops.
8. Diagnostics explain common connection failures.
9. Manual validation queue passes on physical Mac + Android devices.
