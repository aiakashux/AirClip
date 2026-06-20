# AirClip Security Model

This document describes the active LAN-first security model for the Mac + Android AirClip MVP.

The older relay-server security model is legacy. AirClip currently syncs paired devices directly over the local network and stores clipboard history locally on each device.

## Security Goals

AirClip is designed around these goals:

1. Clipboard plaintext should stay on the user's trusted devices.
2. Clipboard packets should be encrypted before network transfer.
3. Only paired devices should be allowed to exchange clips.
4. Removed devices should stop syncing immediately.
5. Sensitive clipboard content should be blocked or confirmed before it is sent.
6. Local history should be under user control.
7. Logs and diagnostics should avoid clipboard plaintext.

## Active Trust Boundary

The active MVP trust boundary is:

```text
Mac AirClip app
  <-> encrypted LAN WebSocket packet
Android AirClip app
```

There is no active relay server in the clipboard delivery path.

The backend source still exists in the repository, but it is not currently trusted with clipboard transport, storage, or catch-up for the LAN-first MVP.

## Device Identity

Each device owns a local AirClip identity:

1. Stable local device ID.
2. Shared AirClip pairing ID.
3. Public/private key material.
4. Locally stored trusted peer records.

Pairing exchanges enough metadata for each device to recognize the other later. A device is trusted only if it is present in the local paired-device registry and matches the expected AirClip identity.

Unknown devices are rejected. Removed devices are rejected even if they still know the old shared AirClip ID.

## Pairing

Pairing is local and user initiated.

Expected pairing properties:

1. The user intentionally opens pairing on both devices.
2. QR or code exchange carries device identity metadata.
3. Each device stores the paired peer locally.
4. Pairing does not require account login for the active MVP.
5. Re-pairing after removal should create a new trusted state.

Manual validation still needs to confirm fresh pairing, removal, reconnect rejection, and re-pairing on physical devices.

## Transport Security

Peers communicate over local WebSocket connections on TCP `7878`.

The transport sequence is:

1. Device discovers a peer through local network discovery.
2. Device opens a LAN WebSocket connection.
3. Peers exchange auth metadata.
4. Each side checks local pairing records.
5. Authenticated peers can exchange clip, history, and heartbeat messages.
6. Invalid or unknown peers are disconnected.

Transport auth is local-device trust, not account-token trust.

## Payload Encryption

Clipboard packets are encrypted before they are sent to a peer.

Current payload rule:

1. Sender captures clipboard data.
2. Sender classifies sensitivity.
3. Sender applies Block, Ask, or Allow policy.
4. Sender encrypts the allowed payload for the peer.
5. Sender transmits the encrypted packet over the authenticated LAN connection.
6. Receiver decrypts locally.

The network should only carry encrypted clipboard payloads plus metadata needed for routing, deduplication, and diagnostics.

## Sensitive Clipboard Protection

Sensitive classification runs locally on macOS and Android.

Covered categories include:

1. Password-like strings.
2. API keys and tokens.
3. Private keys.
4. Recovery phrases.
5. Payment cards.
6. One-time codes.

Each category supports:

1. Block: never send automatically or manually.
2. Ask: block automatic transfer and require explicit confirmation for manual send.
3. Allow: permit automatic and manual sends.

Policy checks are expected on:

1. macOS automatic clipboard capture.
2. macOS main-window send.
3. macOS menu-bar send.
4. Android main-app send.
5. Android widget send.
6. Transport fallback paths that could bypass normal UI.

## Local History

History is local to each device.

Security expectations:

1. Retention is enforced locally.
2. Saved clips are protected from normal pruning.
3. Clear-history and delete-one-item actions persist after restart.
4. History search runs locally.
5. History backfill merges into history without overwriting the active clipboard.

History backfill is a peer-to-peer recovery feature, not cloud storage.

## Device Removal

Removing a paired device should:

1. Delete the local trust record.
2. Disconnect the active peer connection.
3. Reject future auth attempts from that device.
4. Require explicit re-pairing before sync can resume.

This behavior is implemented in code and still waiting for physical end-to-end validation.

## Presence and Heartbeat

Presence is local runtime state.

Current behavior:

1. Peers exchange heartbeat and heartbeat acknowledgement messages.
2. Heartbeats refresh each paired device's last-seen time.
3. UI displays connected or last-seen status.
4. Paused mode tears down listener, browser, advertisement, and active peers.

Presence is not Redis-backed in the active MVP.

## Diagnostics

Diagnostics should help users fix local-network issues without exposing clipboard content.

Allowed diagnostic content:

1. Listener startup failure.
2. Discovery startup failure.
3. Advertisement startup failure.
4. Paused state.
5. Paired-but-no-peer state.
6. Same-Wi-Fi and local-network-permission hints.

Avoid logging:

1. Clipboard plaintext.
2. Sensitive sample values.
3. Private keys.
4. Full decrypted payloads.

Acceptable logs can include lengths, hashes, categories, device labels, and connection lifecycle events when they are useful for debugging.

## Legacy Backend

The legacy backend model assumed:

1. Account login.
2. Device JWTs.
3. Redis presence.
4. Relay WebSocket delivery.
5. Server-side catch-up buffers.

That model is not active for the current LAN-first MVP.

If a backend returns later, it should have a new product/security review. At minimum:

1. Remote relay must be explicit opt-in.
2. Clipboard payloads must remain end-to-end encrypted.
3. Sensitive policies must run before upload.
4. Cloud status must be visible to the user.
5. Server retention must be minimal and user-controlled.
6. Tests must clearly distinguish LAN behavior from relay behavior.

## Threats Addressed

Current safeguards reduce risk from:

1. Accidental sensitive clipboard sync.
2. Unknown LAN peers attempting to connect.
3. Removed devices reconnecting without user approval.
4. Duplicate loops after send, receive, tap-to-copy, or reconnect backfill.
5. Diagnostic logs exposing clipboard plaintext.
6. Local history pruning deleting saved clips unexpectedly.

## Remaining Validation

Security-relevant manual validation still waiting:

1. Fresh pairing from reset state.
2. Removed device cannot reconnect.
3. Re-pairing after removal.
4. Sensitive Block, Ask, and Allow behavior on both platforms.
5. Reconnect backfill does not overwrite active clipboard.
6. Duplicate suppression across live sync, history tap-to-copy, and backfill.
7. Local network permission failure diagnostics.
8. Android clipboard and foreground-service restriction diagnostics.

Use `docs/MANUAL_VALIDATION_QUEUE.md` for the step-by-step validation script.
