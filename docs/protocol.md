# Airclip LAN Protocol

## Transport

- Port: TCP `7878`
- Service: `_airclip._tcp`
- Discovery: Bonjour (macOS), NSD (Android)
- Framing: JSON text messages over WebSocket

## Auth Handshake

Client → Server:
```json
{
  "type": "auth",
  "device_id": "...",
  "airclip_id": "...",
  "public_key": "base64",
  "ssid": "optional"
}
```

Server → Client (success):
```json
{
  "type": "auth_ok",
  "device_id": "...",
  "public_key": "base64",
  "ssid": "optional"
}
```

Reconnects are rejected when the space/device is not trusted or the presented public key differs from the saved pairing key. Reconnect messages cannot rotate pairing keys. **This key pin is not proof of private-key possession:** the current protocol still needs authenticated sessions and replay protection before release.

## Pairing Messages

### pair_probe
```json
{ "type": "pair_probe", "code": "123456" }
```
Response:
```json
{ "type": "pair_info", "device_id": "...", "device_name": "Mac mini", "public_key": "base64", "airclip_id": "..." }
```
or `{ "type": "pair_reject", "reason": "invalid_code" }`

### pair_request
```json
{
  "type": "pair_request",
  "code": "123456",
  "device_id": "...",
  "device_name": "Pixel",
  "platform": "android",
  "public_key": "base64",
  "airclip_id": "..."
}
```
Response:
```json
{
  "type": "pair_ok",
  "airclip_id": "...",
  "all_devices": [{ "device_id": "...", "device_name": "Mac mini", "public_key": "base64", "platform": "mac" }]
}
```
or `{ "type": "pair_reject", "reason": "invalid_code" }`

## Clip Message

```json
{
  "type": "clip",
  "ciphertext": "base64",
  "nonce": "base64",
  "ts": "1760000000000",
  "msg_id": "...",
  "from_device_id": "..."
}
```

Decrypted payload shape:
```json
{ "kindRaw": "text|url|code|color|email|image", "text": "...", "imageDataBase64": null }
```

Encryption: NaCl sealed box with recipient public key. `nonce` field is a sentinel for protocol shape compatibility only.

## History Backfill

Sent after `auth_ok`. Up to the local retained-history limit (currently 500 items) per peer.

```json
{
  "type": "history_clip",
  "ciphertext": "base64",
  "nonce": "base64",
  "ts": "1760000000000",
  "msg_id": "...",
  "from_device_id": "..."
}
```

Receiver merges into local history only. Never writes to system clipboard.

A connected peer can request another backfill without reconnecting:

```json
{ "type": "history_request" }
```

## History Mutations

Deletion state is persisted locally and replayed before history backfill when a peer reconnects.

```json
{ "type": "history_delete", "msg_id": "...", "from_device_id": "...", "ts": "1760000000000" }
```

`from_device_id` and `ts` let upgraded clients remove legacy live-sync copies that were assigned different IDs on each device.

```json
{ "type": "history_clear", "through_ms": "1760000000000" }
```

Receivers persist these tombstones so an offline device cannot restore deleted history during a later backfill.

## Heartbeat

Every 15 seconds while connected.

```json
{ "type": "heartbeat", "ts": "1760000000000", "ssid": "optional" }
```
Reply: `{ "type": "heartbeat_ack", "ts": "...", "ssid": "optional" }`

Refreshes `lastSeenMs` and device presence UI.

## File metadata validation

Transfer/cache identifiers must match `[A-Za-z0-9_-]{1,128}`. File sizes must be nonnegative and names must be nonempty without NUL characters. Both clients reject unsafe remote metadata; cache path access also validates persisted records. This does not replace sender authentication or transfer-integrity testing.
