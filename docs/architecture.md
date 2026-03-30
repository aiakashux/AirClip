# Clipr+ Architecture

This document explains how the Clipr+ system works internally.

It covers:

- system components
- clipboard sync flow
- encryption model
- message delivery
- offline catch-up
- Redis storage model
- sequence ordering

The goal is to make the system easy to understand and maintain.

---

# System Overview

Clipr+ consists of three main components:

```
Client Devices
   │
   │ encrypted clipboard payload
   ▼
Backend Relay Server
   │
   │ WebSocket delivery
   ▼
Other Trusted Devices
```

Main parts:

1. Mac client
2. Android client
3. Backend server
4. Redis storage

The backend acts as a **temporary relay**, not permanent clipboard storage.

---

# Components

## Mac Client

Responsibilities:

- monitor clipboard changes
- encrypt clipboard payload
- send encrypted messages to backend
- maintain WebSocket connection
- receive clipboard messages from other devices

Key features:

- clipboard monitoring
- encryption
- message sending
- message receiving

---

## Android Client

Responsibilities:

- maintain WebSocket connection
- decrypt clipboard payloads
- store clipboard history locally
- display clipboard history
- allow tap-to-copy

Key features:

- local clipboard history
- offline catch-up
- message decryption

---

## Backend Server

Responsibilities:

- device authentication
- message relay
- sequence ordering
- short-term message storage
- WebSocket delivery
- REST catch-up endpoint

Important property:

The backend **does not permanently store clipboard data**.

---

## Redis

Redis is used as a lightweight data layer.

It stores:

- recent clipboard history
- pending delivery queues
- message sequence ordering

Redis keys expire automatically.

---

# Clipboard Sync Flow

When a user copies text on Mac:

### Step 1

Mac detects clipboard change.

### Step 2

Clipboard text is encrypted.

```
plaintext clipboard
      │
      ▼
encrypted payload
```

### Step 3

Encrypted payload is sent to backend via REST.

### Step 4

Backend assigns a **sequence number**.

Example:

```
seq = 101
seq = 102
seq = 103
```

### Step 5

Backend stores message temporarily in Redis.

### Step 6

Backend sends message to connected devices via WebSocket.

### Step 7

Android receives encrypted message.

### Step 8

Android decrypts the payload.

### Step 9

Android stores message in local clipboard history.

---

# Sequence Numbers

Sequence numbers maintain message ordering.

Properties:

- strictly increasing
- assigned by backend
- used for catch-up
- stored in Redis

Example message stream:

```
seq 101
seq 102
seq 103
seq 104
```

Devices track:

```
lastSeenSeq
```

This allows devices to request missed messages.

---

# Offline Catch-Up

If a device goes offline, it may miss messages.

Example:

Android last seen sequence:

```
lastSeenSeq = 100
```

Mac sends messages while Android is offline:

```
101
102
103
104
```

When Android reconnects:

### Step 1

Server sends:

```
hello(latest_seq=104)
```

### Step 2

Android compares:

```
lastSeenSeq = 100
latestSeq = 104
```

### Step 3

Android calls REST endpoint:

```
GET /clips?after_seq=100
```

### Step 4

Server returns messages:

```
101
102
103
104
```

### Step 5

Android decrypts and merges into history.

---

# WebSocket Delivery

When devices are online, clipboard messages are delivered instantly.

Flow:

```
Mac Client
   │
   │ POST /clipboard
   ▼
Backend
   │
   │ deliver_clipboard
   ▼
Android Client
```

WebSocket message types include:

- hello
- deliver_clipboard
- connection events

---

# Redis Storage Model

Redis stores short-term clipboard data.

Main structures:

### Clipboard History

```
clips:hist:{account_id}
```

Type:

```
sorted set
```

Score:

```
sequence number
```

Value:

```
encrypted clipboard payload
```

Purpose:

- catch-up fetch
- ordering

Retention:

```
30 minutes
```

---

### Pending Delivery

```
pending:{device_id}
```

Type:

```
list
```

Purpose:

store messages for temporarily disconnected devices.

TTL:

```
~60 seconds
```

Used for quick reconnect recovery.

---

# Local Clipboard History

Each device keeps its own local history.

Properties:

- newest items first
- max **20 items**
- oldest items removed automatically
- stored locally
- independent from server

Example:

```
[112]
[111]
[110]
[109]
...
```

---

# Encryption Model

Clipboard data is encrypted on the client before transmission.

Encryption flow:

```
Clipboard Text
      │
      ▼
Client Encryption
      │
      ▼
Encrypted Payload
      │
      ▼
Backend Relay
      │
      ▼
Receiving Device
      │
      ▼
Client Decryption
```

Important properties:

- encryption happens on client
- server only relays encrypted payload
- server cannot read clipboard text
- private keys remain on device

---

# Message Lifecycle

A clipboard message goes through these stages:

```
1 Clipboard copied
2 Clipboard encrypted
3 Payload sent to backend
4 Backend assigns sequence
5 Stored in Redis history
6 Delivered via WebSocket
7 Received by device
8 Decrypted by client
9 Stored in local history
```

---

# Failure Handling

### WebSocket disconnect

If WebSocket disconnects:

- client reconnects automatically
- catch-up logic fetches missed items

---

### Decryption failure

If decryption fails:

- message ignored
- sequence not advanced
- client can retry later

---

### History overflow

If more than 20 items exist:

- oldest items are removed.

---

# Design Principles

Clipr+ follows several core design principles.

### Minimal server state

The backend stores only short-lived data.

### Client-owned encryption

Clipboard content is encrypted before leaving the device.

### Event-driven sync

WebSockets provide real-time delivery.

### Deterministic ordering

Sequence numbers ensure consistent message ordering.

### Simple failure recovery

Catch-up mechanism restores missed messages.

---

# Future Architecture Changes

Future improvements may include:

- multi-device fanout optimization
- longer history retention
- improved background sync
- richer clipboard formats
- device trust management

---

# Related Documents

See additional documentation:

```
docs/protocol.md
docs/security.md
docs/mvp-scope.md
```