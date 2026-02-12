# Clipr+ MVP Protocol Specification (v0)

## 1. Scope (MVP Only)

This document defines the protocol and security model for the MVP of Clipr+.

MVP constraints:

* Text clipboard only
* Latest item only (no history)
* Cross-network sync (WiFi ↔ mobile data)
* Central relay server
* End-to-end encrypted
* Per-device keypairs
* Device approval required
* No plaintext stored server-side

Non-goals (MVP):

* File/image/audio sync
* Clipboard history
* LAN peer-to-peer
* Multi-device group encryption optimization
* Stealth Android background mode

---

# 2. Core Concepts

## 2.1 Account

Represents a user identity.

Fields:

* `id` (UUID)
* `email`
* `password_hash`
* `created_at`

An account may have multiple devices.

---

## 2.2 Device

Each physical device registers independently.

Fields:

* `device_id` (UUID)
* `account_id`
* `device_name`
* `platform` (mac, android)
* `public_key` (X25519)
* `trust_status` (`trusted` | `pending`)
* `created_at`
* `last_seen`

Rules:

* First device for an account is automatically `trusted`.
* New devices are `pending` until approved.
* Only `trusted` devices receive clipboard messages.

---

## 2.3 ClipboardMessage

Represents a single encrypted clipboard payload.

Server stores only encrypted data.

Fields:

```
{
  id: uuid,
  from_device_id: string,
  to_device_id: string,
  created_at: timestamp,
  ciphertext: binary,
  nonce: binary,
  version: 1
}
```

Notes:

* One encrypted message per recipient device.
* No plaintext is ever stored server-side.
* Messages expire via TTL (60 seconds).
* Message deleted after ACK.

---

# 3. Cryptography Model

## 3.1 Key Generation

Each device generates locally:

* X25519 keypair

Private key:

* Stored locally only
* Never sent to server

Public key:

* Uploaded during device registration

---

## 3.2 Encryption Strategy (MVP)

When sending clipboard:

1. Sender fetches all `trusted` devices in account.
2. For each trusted recipient:

   * Encrypt plaintext using recipient’s public key.
   * Generate separate ciphertext per recipient.
3. Send encrypted payloads to server.

No shared group keys in MVP.

---

## 3.3 Trust Model (TOFU)

Trust On First Use (TOFU) rules:

* First device is trusted automatically.
* New device is `pending`.
* Existing trusted device must approve.
* Once approved, public key is pinned.
* If a device’s public key changes:

  * Treat as new device
  * Require approval again

This prevents silent public key substitution attacks.

---

# 4. Device Approval Flow

1. New device logs in.
2. Device registers public key.
3. Server sets `trust_status = pending`.
4. Server notifies existing trusted devices.
5. User approves from trusted device.
6. Server updates device to `trusted`.

Only after step 6:

* Device receives clipboard messages.

---

# 5. Transport Layer

Transport: WebSocket over TLS (WSS)

Each device:

* Authenticates
* Connects to `/ws`
* Identified by `device_id`

WebSocket must remain persistent.

Reconnect strategy:

* Auto reconnect on disconnect
* Exponential backoff

---

# 6. WebSocket Events

All messages JSON-based.

## 6.1 Client → Server

### Register Device

```
{
  type: "register_device",
  device_name: "MacBook Pro",
  platform: "mac",
  public_key: "base64"
}
```

### Approve Device

```
{
  type: "approve_device",
  target_device_id: "uuid"
}
```

### Send Clipboard

```
{
  type: "send_clipboard",
  payloads: [
    {
      to_device_id: "uuid",
      ciphertext: "base64",
      nonce: "base64"
    }
  ]
}
```

### ACK

```
{
  type: "ack",
  message_id: "uuid"
}
```

---

## 6.2 Server → Client

### Device Pending

```
{
  type: "device_pending",
  device_id: "uuid",
  device_name: "Pixel 7"
}
```

### Clipboard Deliver

```
{
  type: "deliver_clipboard",
  message_id: "uuid",
  from_device_id: "uuid",
  ciphertext: "base64",
  nonce: "base64"
}
```

---

# 7. Clipboard Logic (Client-Side)

## 7.1 Sending Rules

When clipboard changes:

1. If change originated remotely → ignore.
2. Compute hash of plaintext.
3. If hash equals last sent hash → ignore.
4. Encrypt per trusted recipient.
5. Send via WebSocket.

---

## 7.2 Receiving Rules

When receiving `deliver_clipboard`:

1. If `from_device_id == self` → ignore.
2. Decrypt ciphertext.
3. Set clipboard.
4. Store hash in recent cache.
5. Send ACK.

---

# 8. Loop Prevention

Each client maintains:

* `recent_hashes` (small in-memory list, e.g., last 10)

Rules:

* Do not resend identical content.
* Do not process messages from self.
* Do not resend clipboard change caused by remote update.

This prevents infinite bounce.

---

# 9. Delivery Semantics

MVP uses:

* Latest-only logic
* No permanent history
* Server TTL: 60 seconds
* Message deleted after ACK

If recipient offline:

* Message held in Redis until TTL expires
* Delivered on reconnect

---

# 10. Security Guarantees

If server is compromised, attacker sees:

* Account IDs
* Device IDs
* Public keys
* Encrypted blobs
* Timestamps
* Message sizes

Attacker cannot see:

* Clipboard content
* Private keys
* Decrypted history

---

# 11. Performance Target

* Clipboard sync latency: <2 seconds
* WebSocket persistent connection required
* Android uses foreground service for reliability

---

# 12. Versioning

`version: 1` included in message schema.

Future protocol changes must increment version.

---

# End of MVP Protocol v0

---

