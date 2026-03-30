# Clipr+ Security Model

This document describes the security architecture of Clipr+.

It explains:

- identity model
- cryptography
- key management
- threat model
- server trust assumptions
- attack protections
- MVP limitations

The goal is to clearly document how clipboard data remains private even when passing through a relay server.

---

# 1. Security Goals

Clipr+ is designed with the following security goals.

## Confidentiality

Clipboard content must remain private.

The relay server must **not be able to read clipboard content**.

Clipboard data is encrypted before leaving the sender device.

---

## Device Identity Integrity

Only trusted devices belonging to the same account should be able to:

- send clipboard messages
- receive clipboard messages

Device identity must be strongly bound to cryptographic keys.

---

## Message Authenticity

Devices must be able to verify that messages originate from legitimate trusted devices.

---

## Minimal Server Trust

The server should act only as a relay.

If the server is compromised, attackers must **not gain access to clipboard plaintext**.

---

# 2. Identity Model

Each user has an **account identity** and one or more **device identities**.

```
Account
   ├── Device A (Mac)
   ├── Device B (Android)
   └── Device C (future devices)
```

Each device has its own:

- device_id
- keypair
- device token

Devices operate independently.

---

# 3. Device Keypairs

Each device generates a keypair locally.

Algorithm:

```
X25519
```

Properties:

- fast
- secure
- widely used for key exchange
- small key size

---

## Key Generation

Keypair generation occurs **locally on the device**.

```
private_key ← generated locally
public_key ← derived
```

The private key:

- never leaves the device
- never transmitted to server
- never logged

The public key:

- uploaded during device registration
- stored server-side

---

# 4. Key Storage

## Mac Client

Private key stored locally.

Storage depends on platform implementation.

Expected production storage:

- macOS Keychain

---

## Android Client

Private key stored securely on disk.

Implementation uses:

```
EncryptedSharedPreferences
```

Backed by:

```
Android Keystore
```

Properties:

- AES encryption at rest
- keys tied to device security
- survives application restart
- inaccessible to other apps

Key persistence ensures that:

- clipboard messages received after reconnect can be decrypted
- keys survive process death

---

# 5. Encryption Model

Clipboard encryption occurs **before network transmission**.

The server never receives plaintext.

Encryption flow:

```
Clipboard text
     │
     ▼
Client encryption
     │
     ▼
Encrypted payload
     │
     ▼
Relay server
     │
     ▼
Receiving device
     │
     ▼
Client decryption
```

---

# 6. Per-Recipient Encryption

When a clipboard message is sent:

1. Sender fetches all trusted devices.
2. For each device:

```
ciphertext = encrypt(plaintext, recipient_public_key)
```

3. Separate encrypted payload is generated per recipient.

Example:

```
Mac → Android

plaintext: "example"

ciphertext_A = encrypt(example, Android_public_key)
ciphertext_B = encrypt(example, iPad_public_key)
```

Each recipient receives only the payload intended for them.

This avoids:

- shared group keys
- key compromise across devices

---

# 7. Message Contents

Encrypted message structure:

```
{
  id,
  seq,
  from_device_id,
  to_device_id,
  ciphertext,
  nonce,
  version
}
```

Server can see:

- device IDs
- timestamps
- encrypted blobs

Server cannot see:

- clipboard text
- decrypted payload

---

# 8. Trust Model (TOFU)

Clipr+ uses **Trust On First Use (TOFU)**.

Rules:

1. First device is trusted automatically.
2. New devices are `pending`.
3. Existing trusted device must approve them.
4. Once approved, the device public key is pinned.

---

## Public Key Pinning

Each trusted device has a pinned public key.

If a device reconnects with a different key:

```
treat as new device
```

Approval required again.

This prevents:

- silent key replacement
- impersonation attacks

---

# 9. Token Security

Two token types exist.

## Account Token

Used for account-level operations:

- login
- device registration
- device approval

Restrictions:

- cannot be used for WebSocket messaging

---

## Device Token

Used for messaging.

Contains:

```
device_id
account_id
token_type=device
```

Rules:

- WebSocket must accept **only device tokens**
- Device ID must be derived from token
- Client-provided device_id must be ignored

This prevents identity spoofing.

---

# 10. WebSocket Security

Transport:

```
WSS (WebSocket over TLS)
```

Security properties:

- encrypted transport
- protection against network sniffing
- token-based authentication

Connections require valid device token.

---

# 11. Clipboard Loop Prevention

Clipboard sync systems can accidentally create infinite loops.

Example:

```
Mac → Android → Mac → Android
```

To prevent this, clients implement safeguards.

Each device maintains:

```
recent_hashes
```

Rules:

1. If clipboard change came from remote → ignore.
2. If hash equals recent hash → ignore.
3. If message originates from self → ignore.

---

# 12. Replay Protection

Replay attacks attempt to resend old messages.

Protection mechanisms:

- sequence numbers
- lastSeenSeq tracking
- deduplication checks

Messages with:

```
seq <= lastSeenSeq
```

are ignored.

---

# 13. Server Compromise Scenario

If the backend server is compromised, attackers may obtain:

- account IDs
- device IDs
- public keys
- encrypted clipboard blobs
- timestamps
- message sizes

Attackers **cannot obtain**:

- clipboard plaintext
- device private keys
- decrypted clipboard history

This protects user clipboard content even under server compromise.

---

# 14. Potential Threats

## Network interception

Mitigation:

```
TLS (HTTPS / WSS)
```

---

## Server compromise

Mitigation:

```
end-to-end encryption
```

---

## Device impersonation

Mitigation:

- device tokens
- public key pinning
- trust approval workflow

---

## Clipboard replay attacks

Mitigation:

- sequence numbers
- deduplication
- message ordering checks

---

# 15. MVP Security Limitations

The MVP intentionally keeps scope small.

Current limitations:

- no secure enclave usage on Mac yet
- Android background service still evolving
- device approval UX is minimal
- server still handles metadata
- no forward secrecy group protocol yet

These may be improved in future versions.

---

# 16. Future Security Improvements

Possible future enhancements:

### Hardware-backed keys

Use hardware secure elements when available.

### Device fingerprint verification

Display fingerprint during approval.

### Forward secrecy

Introduce ephemeral session keys.

### Multi-device group encryption

Replace per-recipient encryption with group key distribution.

### Stronger device verification

Add QR-code based pairing.

---

# 17. Security Principles

Clipr+ follows several core principles.

**Encrypt before network transmission**

Clipboard plaintext must never leave the device.

**Minimize server trust**

The server should only relay encrypted data.

**Strong device identity**

Every device must have a unique cryptographic identity.

**Fail safely**

Unknown devices must remain untrusted until explicitly approved.

---

# Related Documents

See additional documentation:

```
docs/architecture.md
docs/protocol.md
docs/mvp-scope.md
```

---

# End of Security Model