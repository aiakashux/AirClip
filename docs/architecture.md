# AirClip Architecture

Status: Current LAN-first architecture.

AirClip is a Mac + Android clipboard sync app that works on the local network first. Clipboard content is encrypted on the sender, sent directly to paired devices over LAN WebSocket connections, and stored only in local device history.

## Product Shape

AirClip has two active client apps:

1. macOS app
2. Android app

The active MVP does not depend on the backend relay for clipboard delivery. Older Redis relay, account WebSocket, sequence-number catch-up, and pending device approval assumptions are legacy and should not guide new implementation.

## Components

### macOS App

Responsibilities:

1. Monitor local clipboard changes.
2. Apply sync mode and sensitive clipboard policy.
3. Encrypt clipboard packets for paired peers.
4. Advertise `_airclip._tcp` on the LAN.
5. Browse for paired peers over Bonjour.
6. Accept incoming LAN WebSocket connections on TCP `7878`.
7. Store local clipboard history with saved-item protection.
8. Show device presence, history, settings, and pairing UI.

### Android App

Responsibilities:

1. Monitor or explicitly read clipboard depending on Android platform limits and sync mode.
2. Apply sync mode and sensitive clipboard policy.
3. Encrypt clipboard packets for paired peers.
4. Advertise `_airclip._tcp` using Android NSD.
5. Discover paired peers using Android NSD.
6. Accept incoming LAN WebSocket connections on TCP `7878`.
7. Keep a foreground sync service when LAN sync is active.
8. Store local clipboard history with saved-item protection.
9. Show device presence, history, settings, widget send, and pairing UI.

### Backend

The backend source still exists in the repository, but it is not the active clipboard transport for the LAN-first MVP. Treat it as legacy or future optional infrastructure until a new product decision says otherwise.

## Identity And Pairing

Each device has:

1. `airclip_id`: shared network identifier for the paired AirClip group.
2. `device_id`: unique local device identifier.
3. Device name and platform metadata.
4. Public/private keypair.
5. Local paired-device registry.

Pairing uses QR/code-based local exchange. Paired devices store each other locally. There is no active pending-approval server workflow in the LAN-first MVP.

## Trust Model

A peer is trusted only when:

1. The peer presents the same `airclip_id`.
2. The peer `device_id` exists in the local paired-device registry.

Removing a device deletes it from the local registry and disconnects its active peer. Removed devices should not reconnect until paired again.

## LAN Runtime

Each paired device starts two LAN paths when sync mode allows LAN service:

1. Listener: WebSocket server on TCP `7878`.
2. Discovery/advertisement: `_airclip._tcp` over Bonjour or Android NSD.

Peers authenticate after connection using:

```json
{
  "type": "auth",
  "device_id": "device-id",
  "airclip_id": "airclip-id",
  "public_key": "base64-public-key"
}
```

The receiver replies:

```json
{
  "type": "auth_ok",
  "device_id": "device-id",
  "public_key": "base64-public-key"
}
```

After authentication, the connection carries live clips, history backfill clips, and heartbeat messages.

## Clipboard Flow

When a local clip is sent:

1. App captures the clipboard packet.
2. Sync mode is checked.
3. Sensitive clipboard policy is checked.
4. Packet is saved to local history.
5. Packet is encrypted once per connected peer.
6. Encrypted packet is sent over the authenticated LAN WebSocket.
7. Receiver decrypts it.
8. Receiver writes live clips to the system clipboard.
9. Receiver stores the clip in local history.
10. Echo suppression prevents loops.

History backfill uses the same encrypted packet shape, but it merges into history only and does not overwrite the active clipboard.

## History

History is local-first:

1. Mac stores SwiftData `ClipboardItem` records.
2. Android stores `ClipItemRecord` records in DataStore JSON.
3. Saved clips are protected from normal pruning.
4. Unsaved clips remain bounded by platform retention and item caps.
5. Backfill sends up to 20 recent items after peer authentication.
6. Backfill deduplicates by message ID or source/content/timestamp window.

## Sync Modes

Active sync modes:

1. Auto: automatic capture and LAN service.
2. Manual: explicit send, LAN service still available.
3. Paused: stops listener, discovery, advertisement, service, and peers.

## Presence And Recovery

Connected peers exchange heartbeat and heartbeat acknowledgement messages every 15 seconds. Heartbeats refresh `lastSeenMs` and improve device UI presence.

Recovery is local-network based:

1. Devices reconnect when Bonjour/NSD discovers the paired peer again.
2. Peers authenticate using local trust checks.
3. Each side pushes recent encrypted history after authentication.
4. History backfill merges without changing the active clipboard.

## Security

Security properties:

1. Clipboard plaintext is encrypted before transport.
2. Private keys remain local.
3. LAN auth rejects removed or unknown devices.
4. Sensitive-content policies can block or confirm sends before encryption.
5. Logs should contain only lengths, hashes, categories, and metadata, not plaintext clipboard content.

## Current Non-Goals

1. Permanent cloud clipboard history.
2. Central relay delivery.
3. Redis sequence catch-up.
4. Server-side device approval.
5. iOS background clipboard monitoring.
6. Windows support before Mac + Android are trusted.
