# Design: Auto-Trust + Device Presence
**Date:** 2026-03-30
**Status:** Approved

---

## Problem

New devices register with `trust_status = "pending"` and require explicit approval from an existing trusted device before they can send or receive clipboard data. This approval step adds friction and is no longer needed. All devices registered with valid account credentials should be immediately trusted.

Additionally, there is no way to know whether a device is currently online. This system adds a lightweight Redis-backed presence layer to replace the approval status signal.

---

## Scope

Backend only (`backend/app/`). No changes to JWT structure, token enforcement, encryption, loop prevention, sequence ordering, or message delivery.

---

## Changes

### 1. Registration — always trusted

`storage.create_device()` already sets `trust_status = "trusted"` (existing "DEV MODE" comment). No storage change needed.

In `devices.py` `POST /register`:
- Verify no code path sets or references `"pending"` after `create_device()` returns
- Response already includes `trust_status = "trusted"` via `DeviceRegisterResponse`

### 2. Remove approval REST endpoint

Delete `POST /devices/{device_id}/approve` from `devices.py`. FastAPI will return 404 for that path after removal.

### 3. Remove approve_device WebSocket handler

Remove from `ws.py`:
- `handle_approve_device()` function
- `handle_register_device()` function (WS-based device creation; registration is REST-only)
- Dispatch cases for `"approve_device"` and `"register_device"` in `websocket_endpoint()`

Remove from `schemas.py`:
- `WSApproveDevice`
- `WSRegisterDevice`
- `WSDevicePending`

### 4. Presence system

**Redis key:** `presence:{device_id}` = `"online"`, TTL = 45 seconds

**Rules:**
- WebSocket connect → `SET presence:{device_id} "online" EX 45`
- Heartbeat received → `EXPIRE presence:{device_id} 45` (resets TTL)
- WebSocket disconnect → `DEL presence:{device_id}`

**Heartbeat event** (client → server):
```json
{ "type": "heartbeat" }
```
No response sent. Handler calls `update_device_last_seen()` as a side-effect.

**New handler in `ws.py`:** `handle_heartbeat(device_id)` — sets presence TTL, updates last_seen.

**New storage function in `storage.py`:** `set_presence(device_id)`, `delete_presence(device_id)`, `is_online(device_id)`.

### 5. GET /devices — add is_online

`DeviceResponse` schema gains one field:
```python
is_online: bool
```

`list_devices()` in `storage.py` checks `Redis.exists(f"presence:{device_id}")` for each device and attaches the boolean.

The REST handler in `devices.py` requires no changes beyond using the updated `DeviceResponse`.

---

## Security constraints (unchanged)

- Server still cannot read clipboard content
- Device token required for WebSocket auth
- Account token required for REST endpoints
- `trust_status` check on send/receive remains in code (always passes now, but must not be removed)

---

## Verification checklist

1. Register new device → `trust_status = "trusted"` in response
2. Connect via WebSocket → `presence:{device_id}` key exists in Redis with TTL ≈ 45s
3. Send heartbeat → TTL resets to 45s
4. Disconnect → `presence:{device_id}` key deleted
5. `GET /devices` → `is_online` reflects live Redis state
6. Send `{"type": "approve_device", ...}` via WebSocket → error or unrecognized event
7. `POST /devices/{id}/approve` → 404

---

## Files changed

| File | Change |
|---|---|
| `backend/app/devices.py` | Remove approve endpoint; verify registration path |
| `backend/app/ws.py` | Remove approve_device + register_device handlers; add heartbeat handler; set/delete presence on connect/disconnect |
| `backend/app/schemas.py` | Remove WSApproveDevice, WSRegisterDevice, WSDevicePending; add is_online to DeviceResponse |
| `backend/app/storage.py` | Add set_presence, delete_presence, is_online helpers; update list_devices to attach is_online |

---

## Out of scope

- Client-side changes (Mac, Android)
- JWT structure changes
- Any other WebSocket handlers
- New dependencies
