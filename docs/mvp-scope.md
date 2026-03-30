# Clipr+ MVP Scope

This document defines the **exact scope of the Clipr+ Minimum Viable Product (MVP)**.

It clarifies:

- what features are included
- what behaviors are guaranteed
- what is intentionally excluded
- what future versions may add

The purpose is to prevent scope creep and keep development focused.

---

# 1. MVP Objective

The goal of the MVP is to prove that **secure cross-device clipboard sync works reliably across networks**.

The MVP focuses on:

```
Mac → Android clipboard synchronization
```

Key design principles:

- simple architecture
- encrypted clipboard transport
- minimal server state
- reliable reconnect behavior

The MVP is not intended to be a complete product.

---

# 2. Supported Platforms

### Included

| Platform | Status |
|--------|-------|
| macOS | Sender + receiver |
| Android | Receiver + history |

---

### Not Included

| Platform | Status |
|--------|-------|
| Windows | Not implemented |
| iOS | Not implemented |
| Linux desktop | Not implemented |

---

# 3. Core Features

## 3.1 Cross-Device Clipboard Sync

Clipboard text copied on one device appears on other trusted devices.

Example flow:

```
User copies text on Mac
        ↓
Mac encrypts clipboard
        ↓
Backend relays encrypted message
        ↓
Android receives message
        ↓
Android decrypts and stores item
```

Target latency:

```
< 2 seconds
```

---

## 3.2 End-to-End Encrypted Clipboard

Clipboard content is encrypted before leaving the device.

Properties:

- encryption performed client-side
- server only sees encrypted payload
- devices decrypt locally

The server cannot read clipboard text.

---

## 3.3 Trusted Device Model

Devices must be approved before participating in clipboard sync.

Rules:

- first device is automatically trusted
- new devices start as `pending`
- trusted devices must approve them

Only trusted devices may:

- send clipboard messages
- receive clipboard messages

---

## 3.4 Device Keypairs

Each device generates a cryptographic keypair.

Algorithm:

```
X25519
```

Private key:

- stored locally
- never sent to server

Public key:

- uploaded during device registration

Used for encrypting clipboard payloads.

---

## 3.5 Clipboard History

Each device maintains local clipboard history.

Properties:

```
max items: 20
ordering: newest first
storage: local device only
```

History allows users to tap previous entries and copy them again.

---

## 3.6 Real-Time Delivery

Devices maintain a persistent WebSocket connection.

This enables near-instant clipboard delivery.

Transport:

```
WSS (WebSocket over TLS)
```

---

## 3.7 Offline Catch-Up

If a device is offline, it can recover missed clipboard messages.

Mechanism:

```
sequence numbers
```

Each message receives a `seq`.

Devices track:

```
lastSeenSeq
```

Reconnect flow:

```
client reconnects
server sends latest_seq
client requests missing messages
server returns encrypted messages
client decrypts and merges history
```

---

# 4. Server Responsibilities

The backend server acts as a **temporary relay**.

Responsibilities:

- device authentication
- message routing
- sequence assignment
- short-term storage
- WebSocket delivery

The server does **not permanently store clipboard data**.

---

# 5. Server Storage Model

The server uses Redis.

Redis stores:

```
short clipboard history
sequence ordering
pending reconnect messages
```

History properties:

```
max entries: 20
retention: ~30 minutes
```

Older entries expire automatically.

---

# 6. Clipboard Message Size

MVP assumes small clipboard text.

Typical examples:

```
URLs
short text
code snippets
```

Large payloads are not optimized.

---

# 7. Loop Prevention

Clipboard systems can create infinite loops.

Example:

```
Mac → Android → Mac → Android
```

MVP clients implement protections:

- ignore messages from self
- hash recent clipboard values
- ignore duplicate hashes
- ignore remote-triggered clipboard events

---

# 8. Reliability Expectations

The MVP aims to be reliable but not production-grade.

Expected behavior:

| Scenario | Expected Result |
|-------|---------------|
| Both devices online | instant sync |
| Android reconnects | catch-up occurs |
| Temporary disconnect | automatic recovery |
| Clipboard duplicates | ignored |

---

# 9. Security Guarantees

Clipboard content is protected by:

- client-side encryption
- device keypairs
- token-based device identity
- TLS transport

The relay server cannot read clipboard text.

---

# 10. Known MVP Limitations

The following limitations are intentional.

### Platform Coverage

- Windows not supported
- iOS not supported

---

### Clipboard Types

Supported:

```
plain text only
```

Not supported:

```
images
files
rich clipboard formats
```

---

### Server Role

Server still sees:

- device IDs
- timestamps
- message sizes

Metadata protection is not implemented.

---

### Background Behavior

Android background reliability may vary depending on device manufacturer.

Stealth background mode is not implemented.

---

### Device Management UX

Device approval UI is minimal.

Advanced device management features are not included.

---

# 11. Performance Targets

MVP targets:

```
clipboard sync latency < 2 seconds
```

Assumes:

- stable network
- active WebSocket connection

---

# 12. Out of Scope for MVP

The following features are intentionally excluded.

```
cross-device clipboard search
pinned clipboard items
permanent cloud clipboard history
LAN peer-to-peer sync
image clipboard sync
file clipboard sync
multi-device group encryption
advanced device trust UI
analytics
telemetry
```

---

# 13. Future Roadmap

Potential improvements after MVP.

### Platform Support

```
Windows client
iOS client
Linux desktop
```

---

### Clipboard Features

```
image clipboard sync
file clipboard sync
rich content clipboard
searchable history
pinned clips
```

---

### Sync Improvements

```
improved Android background service
better reconnect handling
larger history window
LAN optimization
```

---

### Security Enhancements

```
hardware-backed keys
QR-code device pairing
forward secrecy sessions
group encryption
```

---

# 14. Definition of MVP Success

The MVP is considered successful if:

1. Clipboard text copied on Mac reliably appears on Android.
2. Clipboard payloads remain encrypted end-to-end.
3. Offline reconnect successfully recovers missed messages.
4. Clipboard loops are prevented.
5. Sync works across different networks.

---

# Related Documentation

See other project documentation:

```
docs/architecture.md
docs/protocol.md
docs/security.md
```

---

# End of MVP Scope