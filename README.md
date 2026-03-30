# Clipr+

Clipr+ is a secure cross-device clipboard synchronization system.

It allows text copied on one device to instantly appear on other trusted devices.

The current MVP focuses on **Mac → Android clipboard sync** with:

- encrypted payload transport
- WebSocket real-time delivery
- offline catch-up support
- local clipboard history

The server acts only as a **temporary relay**, not a permanent storage layer.

---

# Why Clipr+ Exists

Copying information between devices is still unnecessarily difficult.

Typical workflow today:

1. Copy text on laptop
2. Open messaging app
3. Send text to yourself
4. Open phone
5. Copy again

Clipr+ removes that friction.

Copy on one device → paste on another.

---

# MVP Scope

This project currently implements a minimal but functional system:

| Capability | Status |
|------------|-------|
| Mac → Android clipboard sync | ✅ |
| WebSocket real-time delivery | ✅ |
| Offline catch-up | ✅ |
| Encrypted clipboard payloads | ✅ |
| Android clipboard history | ✅ |
| Tap-to-copy from history | ✅ |

Not included in MVP:

- Windows client
- iOS client
- permanent clipboard cloud storage
- rich clipboard types (images/files)
- device management UI

---

# Supported Platforms

### Mac Client
- Clipboard monitoring
- Encryption
- Sending clipboard payloads

### Android Client
- WebSocket connection
- Decryption
- Local clipboard history
- Tap-to-copy UI

### Backend Server
- REST API
- WebSocket relay
- Redis storage

---

# System Architecture

Clipr+ consists of three main layers.

```
Mac Client
    │
    │ encrypted clipboard payload
    ▼
Backend Server
    │
    │ WebSocket relay
    ▼
Android Client
```

Supporting services:

```
Backend
 ├─ REST API
 ├─ WebSocket server
 └─ Redis

Redis
 ├─ short clipboard history
 ├─ pending delivery queue
 └─ sequence ordering
```

The backend **never permanently stores clipboard content**.

---

# Clipboard Sync Flow

When a user copies text on Mac:

1. Mac detects clipboard change
2. Clipboard text is encrypted
3. Encrypted payload is sent to backend
4. Backend assigns sequence number
5. Backend stores short-term history
6. Backend pushes event via WebSocket
7. Android receives encrypted payload
8. Android decrypts message
9. Android stores item in local history

---

# Offline Catch-Up Flow

If Android is offline:

1. Mac copies clipboard items
2. Backend stores recent items temporarily
3. Android reconnects later
4. Server sends `latest_seq`
5. Android compares with `lastSeenSeq`
6. Android fetches missed clips
7. Android decrypts and merges history

Catch-up window:

- **30 minutes**
- **max 20 items**

---

# Security Model

Clipboard data is encrypted **before leaving the sender device**.

Key properties:

- encryption happens on the client
- server relays encrypted payload only
- devices own their private keys
- Android stores keypair securely
- plaintext clipboard data is never logged

The backend cannot read clipboard content.

---

# Local Clipboard History

Each device maintains its own clipboard history.

Properties:

- newest items first
- max **20 items**
- oldest items removed automatically
- stored locally on device
- tap any item to copy it again

---

# Project Structure

```
Clipr+
│
├── backend
│   ├── api
│   ├── websocket
│   └── redis
│
├── mac
│   └── macOS clipboard client
│
├── android
│   └── Android clipboard client
│
└── docs
    ├── architecture.md
    ├── protocol.md
    ├── security.md
    └── mvp-scope.md
```

---

# Running the Project

## 1. Start Backend

Requires:

- Python
- Redis
- Docker (optional)

Example:

```bash
docker-compose up
```

or run Redis + backend manually.

---

## 2. Run Mac Client

Navigate to:

```
/mac
```

Run the Mac client.

The client:

- monitors clipboard
- encrypts clipboard text
- sends messages to backend

---

## 3. Run Android Client

Open the Android project in **Android Studio**.

Build and run the app.

The Android client will:

- connect to backend
- receive clipboard messages
- decrypt payloads
- store local clipboard history

---

# Debug Tools

The Android client currently includes a debug screen that shows:

- WebSocket connection status
- received clipboard messages
- catch-up events
- message sequence numbers

This UI will be removed or hidden in later versions.

---

# Known MVP Limitations

Current limitations are intentional to keep the system simple.

- text clipboard only
- short server retention window
- no Windows client
- no iOS client
- minimal device management
- debug surfaces still present
- limited Android background behavior

---

# Roadmap

Future work may include:

### Platform Support
- Windows client
- iOS client

### Clipboard Improvements
- image clipboard sync
- file clipboard sync
- pinned clipboard items
- searchable history

### Sync Improvements
- improved background reliability
- smarter catch-up
- better device trust UX

---

# Development Philosophy

Clipr+ is intentionally designed to be:

- simple
- secure
- minimal server state
- easy to reason about

The goal is to keep the system **small but reliable**, rather than building a heavy cloud clipboard service.

---

# License

License will be defined before public release.

---

# Documentation

Additional technical documentation is available in:

```
docs/
```

- `architecture.md`
- `protocol.md`
- `security.md`
- `mvp-scope.md`
- `security.md`
