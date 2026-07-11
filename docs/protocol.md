# AirClip LAN Protocol

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

Peer rejected if `airclip_id` or `device_id` not in local registry. Connection closed immediately.

## Pairing Messages

### pair_probe
```json
{ "type": "pair_probe", "code": "12345678" }
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
  "code": "12345678",
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
{ "type": "clip", "ciphertext": "base64", "nonce": "base64" }
```

Decrypted payload shape:
```json
{ "kindRaw": "text|url|code|color|email|image", "text": "...", "imageDataBase64": null }
```

Encryption: NaCl sealed box with recipient public key. `nonce` field is a sentinel for protocol shape compatibility only.

## History Backfill

Sent after `auth_ok`. Up to 20 recent items per peer.

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

## Heartbeat

Every 15 seconds while connected.

```json
{ "type": "heartbeat", "ts": "1760000000000", "ssid": "optional" }
```
Reply: `{ "type": "heartbeat_ack", "ts": "...", "ssid": "optional" }`

Refreshes `lastSeenMs` and device presence UI.
