# AirClip Backend — Feature Gap Implementation Spec
**Date:** 2026-04-09
**Scope:** 5 gaps identified from frontend/backend audit
**Backend stack:** FastAPI + Redis (no SQL)
**Constraint:** Do NOT change WebSocket protocol framing (client code is frozen)

---

## Overview of Changes per File

| File | Changes |
|------|---------|
| `app/schemas.py` | Add `clip_type` to payloads; add `AccountSettings`, `AccountProfile`, `DeviceUpdateRequest` |
| `app/storage.py` | Add `clip_type` to stored clips; add `get/set_account_settings`; add `get_account_profile`; add `update_device_name`, `delete_device` |
| `app/clips.py` | Return `clip_type` in `ClipHistoryItem` responses |
| `app/devices.py` | Add `PATCH /devices/{device_id}` and `DELETE /devices/{device_id}` |
| `app/account.py` | **NEW FILE** — `GET /account/me` and `GET /PATCH /account/settings` |
| `app/main.py` | Register new `account_router` |
| `app/ws.py` | Accept and store `clip_type` from `send_clipboard` payloads |

---

## Gap 1 — Clip Type

### Problem
The frontend detects `clip_type` (url / code / color / text) locally after decryption.
The backend never sees it. Clients cannot filter or display type metadata from the REST history endpoint.

### Design Decision
The **sending client** appends `clip_type` to each payload before encrypting. It is plain-text metadata — not sensitive, since it describes the format (url/code/etc), not the content. The backend stores and forwards it unchanged.

> Note: If stricter privacy is required later, `clip_type` can be encrypted separately. Scope it as plaintext for v1.

### Schema changes — `schemas.py`

```python
# In ClipboardPayload — add optional clip_type
class ClipboardPayload(BaseModel):
    to_device_id: str
    ciphertext: str   # base64
    nonce: str        # base64
    clip_type: str = "text"   # "url" | "code" | "color" | "text"

# In ClipboardMessage — add clip_type
class ClipboardMessage(BaseModel):
    id: str
    from_device_id: str
    to_device_id: str
    created_at: datetime
    ciphertext: str
    nonce: str
    clip_type: str = "text"
    version: int = 1

# In ClipHistoryItem — add clip_type
class ClipHistoryItem(BaseModel):
    seq: int
    message_id: str
    from_device_id: str
    ciphertext: str
    nonce: str
    clip_type: str = "text"

    @field_serializer("seq")
    def serialize_seq(self, v: int) -> str:
        return str(v)
```

### WebSocket handler change — `ws.py`

In `handle_send_clipboard`, extract `clip_type` from each payload and include it in the stored message dict:

```python
# In handle_send_clipboard, inside the for-loop:
clip_type = payload.get("clip_type", "text")

msg = ClipboardMessage(
    id=msg_id,
    from_device_id=caller_device_id,
    to_device_id=to_device_id,
    created_at=datetime.now(timezone.utc),
    ciphertext=payload["ciphertext"],
    nonce=payload["nonce"],
    clip_type=clip_type,        # NEW
)

msg_dict = {**msg.model_dump(mode="json"), "seq": seq}
```

The `WSDeliverClipboard` schema does NOT need `clip_type` — it is already delivered via the catch-up REST endpoint. Real-time delivery is encrypted payload only.

### REST change — `clips.py`

In `get_clips`, include `clip_type` when constructing the response:

```python
return [
    ClipHistoryItem(
        seq=c["seq"],
        message_id=c["id"],
        from_device_id=c["from_device_id"],
        ciphertext=c["ciphertext"],
        nonce=c["nonce"],
        clip_type=c.get("clip_type", "text"),   # NEW
    )
    for c in clips
]
```

No storage changes needed — `clip_type` is already present in the stored `msg_dict`.

---

## Gap 2 & 3 — Settings Persistence + History Depth

### Problem
All settings (auto-sync, history depth, encryption toggle) are ephemeral `@State` on the client. They reset on relaunch. No cross-device sync.

### Design Decision
- A single JSON document per account stored at `account:settings:{account_id}` in Redis (no TTL — persists indefinitely).
- `history_days` is stored and returned to clients. Actual enforcement is client-side (local SwiftData pruning). The 30-min catch-up buffer TTL in Redis is **not changed** — it is an infrastructure concern, not a user preference.
- `encryption_enabled` flag is stored but **not enforced server-side in v1** — the backend always handles ciphertext as opaque bytes. This is a client hint only.

### Schema additions — `schemas.py`

```python
class AccountSettings(BaseModel):
    sync_enabled: bool = True
    history_days: int = 30          # 7 | 30 | 90
    encryption_enabled: bool = True

class AccountSettingsUpdate(BaseModel):
    sync_enabled: bool | None = None
    history_days: int | None = None
    encryption_enabled: bool | None = None
```

### Storage additions — `storage.py`

```python
VALID_HISTORY_DAYS = {7, 30, 90}

async def get_account_settings(account_id: str) -> dict:
    r = get_redis()
    data = await r.get(f"account:settings:{account_id}")
    if not data:
        return {"sync_enabled": True, "history_days": 30, "encryption_enabled": True}
    return json.loads(data)

async def update_account_settings(account_id: str, patch: dict) -> dict:
    settings = await get_account_settings(account_id)
    if "sync_enabled" in patch and patch["sync_enabled"] is not None:
        settings["sync_enabled"] = bool(patch["sync_enabled"])
    if "history_days" in patch and patch["history_days"] is not None:
        if patch["history_days"] not in VALID_HISTORY_DAYS:
            raise ValueError(f"history_days must be one of {VALID_HISTORY_DAYS}")
        settings["history_days"] = patch["history_days"]
    if "encryption_enabled" in patch and patch["encryption_enabled"] is not None:
        settings["encryption_enabled"] = bool(patch["encryption_enabled"])
    r = get_redis()
    await r.set(f"account:settings:{account_id}", json.dumps(settings))
    return settings
```

### New router — `account.py`

```python
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from . import storage
from .auth import get_current_user
from .schemas import AccountSettings, AccountSettingsUpdate

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/settings", response_model=AccountSettings)
async def get_settings(account: dict = Depends(get_current_user)):
    settings = await storage.get_account_settings(account["id"])
    return AccountSettings(**settings)


@router.patch("/settings", response_model=AccountSettings)
async def update_settings(
    req: AccountSettingsUpdate,
    account: dict = Depends(get_current_user),
):
    try:
        settings = await storage.update_account_settings(account["id"], req.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return AccountSettings(**settings)
```

---

## Gap 4 — Account Profile

### Problem
The frontend shows email and a hardcoded "Free" plan badge. There is no `/account/me` endpoint — the client has no way to fetch account details after login.

### Design Decision
- Add `GET /account/me` returning email, account_id, plan, and created_at.
- `plan` is hardcoded `"free"` for all accounts in v1. The field exists in the schema so it is easy to upgrade later.
- `password_hash` is never exposed.

### Schema additions — `schemas.py`

```python
class AccountProfile(BaseModel):
    account_id: str
    email: str
    plan: str        # "free" for all accounts in v1
    created_at: datetime
```

### Router addition — `account.py` (same file as Gap 2/3)

```python
@router.get("/me", response_model=AccountProfile)
async def get_profile(account: dict = Depends(get_current_user)):
    return AccountProfile(
        account_id=account["id"],
        email=account["email"],
        plan=account.get("plan", "free"),
        created_at=account["created_at"],
    )
```

---

## Gap 5 — Device Rename + Delete

### Problem
- Backend only accepts `device_name` at registration. No way to rename post-registration.
- No endpoint to remove a device. A revoked device token stays valid until JWT expiry.

### Design Decision
- `PATCH /devices/{device_id}` — rename only (name is the only mutable field for v1).
- `DELETE /devices/{device_id}` — removes device from the account's set, deletes device record and presence key. The JWT for that device remains technically valid until expiry but the WebSocket handler will reject it (device not found check in `websocket_endpoint`).
- Both endpoints require an **account-scoped** token (not device-scoped) and verify ownership.

### Schema additions — `schemas.py`

```python
class DeviceUpdateRequest(BaseModel):
    device_name: str
```

### Storage additions — `storage.py`

```python
async def update_device_name(device_id: str, device_name: str) -> Optional[dict]:
    device = await get_device(device_id)
    if not device:
        return None
    device["device_name"] = device_name
    r = get_redis()
    await r.set(f"device:{device_id}", json.dumps(device))
    return device

async def delete_device(account_id: str, device_id: str) -> bool:
    """Remove device record, presence key, and set membership. Returns False if not found."""
    device = await get_device(device_id)
    if not device or device["account_id"] != account_id:
        return False
    r = get_redis()
    await r.delete(f"device:{device_id}")
    await r.delete(f"presence:{device_id}")
    await r.srem(f"account:{account_id}:devices", device_id)
    return True
```

### Router additions — `devices.py`

```python
from .schemas import DeviceRegisterRequest, DeviceRegisterResponse, DeviceResponse, DeviceUpdateRequest

@router.patch("/{device_id}", response_model=DeviceResponse)
async def rename_device(
    device_id: str,
    req: DeviceUpdateRequest,
    account: dict = Depends(get_current_user),
):
    device = await storage.get_device(device_id)
    if not device or device["account_id"] != account["id"]:
        raise HTTPException(status_code=404, detail="Device not found")
    updated = await storage.update_device_name(device_id, req.device_name)
    updated["is_online"] = await storage.is_online(device_id)
    return DeviceResponse(**updated)


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: str,
    account: dict = Depends(get_current_user),
):
    removed = await storage.delete_device(account["id"], device_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Device not found")
```

---

## `main.py` — Register new router

```python
from .account import router as account_router   # NEW

app.include_router(auth_router)
app.include_router(account_router)              # NEW
app.include_router(devices_router)
app.include_router(clips_router)
app.add_api_websocket_route("/ws", websocket_endpoint)
```

---

## Complete API Surface After Changes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | — | Register account |
| POST | `/auth/login` | — | Login, get account JWT |
| GET | `/account/me` | account JWT | Profile (email, plan) |
| GET | `/account/settings` | account JWT | Fetch settings |
| PATCH | `/account/settings` | account JWT | Update settings |
| POST | `/devices/register` | account JWT | Register device, get device JWT |
| GET | `/devices/` | account JWT | List devices |
| PATCH | `/devices/{id}` | account JWT | Rename device |
| DELETE | `/devices/{id}` | account JWT | Remove device |
| GET | `/clips/` | device JWT | Fetch clip history (paginated) |
| GET | `/clips/latest_seq` | device JWT | Get latest seq |
| WS | `/ws` | device JWT (header) | Real-time sync |

---

## Implementation Order

1. **`schemas.py`** — all schema additions (no side effects, safe to do first)
2. **`storage.py`** — all storage functions
3. **`account.py`** — new file, register in `main.py`
4. **`devices.py`** — add `PATCH` and `DELETE` routes
5. **`ws.py`** — add `clip_type` extraction in `handle_send_clipboard`
6. **`clips.py`** — add `clip_type` to REST response

Each step is independently testable.
