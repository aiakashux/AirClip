# Clipr+ MVP Protocol Specification (v1)

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
* Only `trusted` devices may:
  * Receive clipboard messages.
  * Send clipboard messages.
  * Approve other devices.

---

## 2.3 ClipboardMessage

Represents a single encrypted clipboard payload.

Server stores only encrypted data.

{
id: uuid,
from_device_id: string,
to_device_id: string,
created_at: timestamp,
ciphertext: binary,
nonce: binary,
version: 1
}


Notes:

* One encrypted message per recipient device.
* No plaintext is ever stored server-side.
* Messages expire via TTL (60 seconds).
* Message deleted after valid ACK from intended recipient.

---

# 3. Cryptography & Identity Model

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
  * Treat as a new device
  * Require approval again

### Public Key Uniqueness Guarantee

Before promoting a device from `pending` to `trusted`:

* Server must verify that no other trusted device
  within the same account has the same `public_key`.

If conflict exists:

* Approval must be rejected (409 Conflict).

This prevents duplicate trusted identities and preserves TOFU integrity.

---

## 3.4 Token Model

Two distinct JWT types exist.

### Account Token

Used for REST endpoints.

Claims:

{
sub: account_id,
token_type: "account"
}


Rules:

* Used for:
  * Device registration
  * Device approval
  * Device listing
* Must NOT be accepted by WebSocket.
* REST endpoints must reject tokens where `token_type != "account"`.

---

### Device Token

Issued after successful device registration.

Claims:

{
sub: account_id,
device_id: device_id,
token_type: "device"
}


Rules:

* Used exclusively for WebSocket connections.
* WebSocket must reject tokens where `token_type != "device"`.
* WebSocket must derive `device_id` only from JWT.
* Client-provided device_id values must be ignored.
* Device tokens must NOT be accepted by REST endpoints.

This enforces strict identity separation between:
- Account-level management
- Device-level messaging

---

# 4. Device Approval Flow

1. User authenticates (account token).
2. Device registers public key.
3. Server sets `trust_status = pending`.
4. Server returns:
   * `device_id`
   * `trust_status`
   * `device_token`
5. Existing trusted device approves pending device.
6. Before promotion:
   * Server revalidates public_key uniqueness.
7. If valid:
   * Device becomes `trusted`.

Only after step 7:

* Device may send clipboard.
* Device may receive clipboard.

---

# 5. Transport Layer

Transport: WebSocket over TLS (WSS)

WebSocket authentication:

* Must use Device Token.
* Must extract `device_id` from JWT.
* Must reject account tokens.
* Must reject tokens missing device_id.

WebSocket connection must remain persistent.

Reconnect strategy:

* Auto reconnect
* Exponential backoff

---

# 6. WebSocket Events

All messages JSON-based.

## 6.1 Client → Server

### Send Clipboard

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


Server rules:

* Sender device must be `trusted`.
* Sender device_id derived from JWT.
* Messages stored with TTL (60s).

---

### Approve Device

{
type: "approve_device",
target_device_id: "uuid"
}


Rules:

* Caller must be `trusted`.
* Approval must re-check public_key uniqueness.

---

### ACK

{
type: "ack",
message_id: "uuid"
}


Rules:

* Server must load message.
* Must verify:
  * `msg.to_device_id == current_device_id`
* Only then delete message.

---

## 6.2 Server → Client

### Clipboard Deliver

{
type: "deliver_clipboard",
message_id: "uuid",
from_device_id: "uuid",
ciphertext: "base64",
nonce: "base64"
}


---

# 7. Clipboard Logic (Client-Side)

## 7.1 Sending Rules

1. If change originated remotely → ignore.
2. Compute hash of plaintext.
3. If hash equals last sent hash → ignore.
4. Encrypt per trusted recipient.
5. Send via WebSocket.

---

## 7.2 Receiving Rules

1. If `from_device_id == self` → ignore.
2. Decrypt ciphertext.
3. Set clipboard.
4. Store hash in recent cache.
5. Send ACK.

---

# 8. Loop Prevention

Each client maintains:

* `recent_hashes` (e.g., last 10)

Rules:

* Do not resend identical content.
* Do not process messages from self.
* Do not resend clipboard change caused by remote update.

---

# 9. Delivery Semantics

MVP behavior:

* Latest-only logic.
* No permanent history.
* Server TTL: 60 seconds.
* Message deleted only after valid ACK.

If recipient offline:

* Message held in Redis.
* Delivered upon reconnect.
* Expires automatically after TTL.

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

Identity spoofing is prevented via:

* Device-bound JWTs
* Strict token type separation
* Public key uniqueness enforcement
* Trust gating on all sensitive actions

---

# 11. Performance Target

* Clipboard sync latency: <2 seconds
* Persistent WebSocket required
* Android must use foreground service

---

# 12. Versioning

`version: 1` included in message schema.

Future protocol changes must increment version.

---

# End of MVP Protocol v1

