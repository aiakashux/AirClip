# AirClip LAN Protocol

Status: Current LAN-first protocol notes.

This document describes the active Mac + Android LAN protocol. The older central relay protocol with account JWTs, pending trust, Redis sequence numbers, and server catch-up is no longer the active MVP protocol.

## Transport

AirClip peers communicate over WebSocket on the local network:

1. TCP port: `7878`
2. Service type: `_airclip._tcp`
3. Discovery: Bonjour on macOS, NSD on Android
4. Payload framing: JSON text messages over WebSocket

## Identity

Each device has:

1. `airclip_id`: shared AirClip group ID.
2. `device_id`: unique device ID.
3. `device_name`
4. `platform`
5. public key
6. local private key

There is no active account token or device JWT requirement in the LAN-first MVP.

## Trust Check

A peer is accepted only when:

1. `airclip_id` matches the local `airclip_id`.
2. `device_id` exists in the local paired-device registry.

Unknown or removed devices are rejected during auth.

## Auth Handshake

Client sends:

```json
{
  "type": "auth",
  "device_id": "device-id",
  "airclip_id": "airclip-id",
  "public_key": "base64-public-key",
  "ssid": "optional-network-name"
}
```

Server replies:

```json
{
  "type": "auth_ok",
  "device_id": "device-id",
  "public_key": "base64-public-key",
  "ssid": "optional-network-name"
}
```

After `auth_ok`, both sides register the peer and may push recent history.

## Pairing Messages

Pairing can use `pair_probe` and `pair_request` before auth.

### Pair Probe

```json
{
  "type": "pair_probe",
  "code": "12345678"
}
```

Success:

```json
{
  "type": "pair_info",
  "device_id": "device-id",
  "device_name": "Mac mini",
  "public_key": "base64-public-key",
  "airclip_id": "airclip-id"
}
```

Failure:

```json
{
  "type": "pair_reject",
  "reason": "invalid_code"
}
```

### Pair Request

```json
{
  "type": "pair_request",
  "code": "12345678",
  "device_id": "device-id",
  "device_name": "Pixel",
  "platform": "android",
  "public_key": "base64-public-key",
  "airclip_id": "airclip-id"
}
```

Success:

```json
{
  "type": "pair_ok",
  "airclip_id": "airclip-id",
  "all_devices": [
    {
      "device_id": "device-id",
      "device_name": "Mac mini",
      "public_key": "base64-public-key",
      "platform": "mac"
    }
  ]
}
```

Failure:

```json
{
  "type": "pair_reject",
  "reason": "invalid_code"
}
```

## Clipboard Packet

Clipboard packets are encoded as JSON before encryption:

```json
{
  "kindRaw": "text",
  "text": "clipboard text",
  "imageDataBase64": null
}
```

Known kinds:

1. `url`
2. `code`
3. `color`
4. `email`
5. `image`
6. `text`

Plain text fallback is still accepted for compatibility.

## Encryption

Clipboard packets are encrypted per recipient using sealed-box encryption with the recipient public key.

Wire fields:

1. `ciphertext`: base64 ciphertext.
2. `nonce`: sentinel value for sealed-box compatibility.

The nonce field remains for protocol shape compatibility even though sealed boxes do not use an explicit nonce.

## Live Clip Message

```json
{
  "type": "clip",
  "ciphertext": "base64",
  "nonce": "base64"
}
```

Receiver behavior:

1. Decrypt.
2. Deduplicate against recent hashes.
3. Store in local history.
4. Write to system clipboard.
5. Update widget/status where applicable.

## History Backfill Message

```json
{
  "type": "history_clip",
  "ciphertext": "base64",
  "nonce": "base64",
  "ts": "1760000000000",
  "msg_id": "message-id",
  "from_device_id": "origin-device-id"
}
```

Receiver behavior:

1. Decrypt.
2. Merge into local history.
3. Deduplicate by message ID or source/content/timestamp window.
4. Do not write to the active system clipboard.

Each peer may push up to 20 recent history records after authentication.

## Heartbeat

Peers exchange heartbeat messages while connected:

```json
{
  "type": "heartbeat",
  "ts": "1760000000000",
  "ssid": "optional-network-name"
}
```

Reply:

```json
{
  "type": "heartbeat_ack",
  "ts": "1760000000000",
  "ssid": "optional-network-name"
}
```

Heartbeat messages refresh local `lastSeenMs` state and device UI presence.

## Loop Prevention

Loop prevention uses:

1. Recent content hashes.
2. Explicit suppression before tap-to-copy writes.
3. Remote-update suppression before live inbound clipboard writes.
4. History backfill merge without clipboard writes.

Text hashes are based on text content. Image hashes are based on image payload when available.

## Error Handling

Invalid initial unauthenticated messages close the connection.

Auth failures close the connection.

Pairing failures return `pair_reject` where possible.

Listener, discovery, and advertisement startup failures are surfaced through runtime diagnostics so the UI can show actionable recovery hints.
