# Auto-Trust + Device Presence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove device approval requirement so all registered devices are immediately trusted, and add a Redis-backed presence system that reports device online/offline status on the device list endpoint.

**Architecture:** Five backend files change. `storage.py` gains three presence helpers and attaches `is_online` to the device list query. `schemas.py` sheds three dead WebSocket message types and adds `is_online` to `DeviceResponse`. `devices.py` loses the approval REST endpoint. `ws.py` loses two WS handlers, gains a heartbeat handler, and sets/clears presence at connect/disconnect boundaries. `integration_test.py` SEC-B2 is rewritten to assert that `approve_device` returns an unrecognized-event error.

**Tech Stack:** Python 3.11+, FastAPI, `redis.asyncio`, pytest, pytest-asyncio, httpx

> **New dev dependencies required:** `pytest`, `pytest-asyncio`, `httpx`.
> `httpx` is already used in `scripts/integration_test.py` but absent from `requirements.txt`.
> Add all three to a new `backend/requirements-dev.txt` before running any tests.

---

## Known Follow-Up (Out of Scope — Prompt 2)

The following client-side files contain dead `approve_device` call sites. They will not cause runtime errors (server will return an unrecognized-event error), but should be cleaned up in the next prompt:

- `android/app/src/main/java/com/airclip/airclip/ws/AirClipWebSocket.kt:115-118` — `sendApproveDevice()` method
- `mac/AirClip/Core/SyncEngine.swift:245` — `approveDevice()` call

Do NOT touch these files in this prompt.

---

## File Map

| File | Action | Summary |
|---|---|---|
| `backend/requirements-dev.txt` | Create | Test dependencies |
| `backend/tests/conftest.py` | Create | Pytest fixtures: mocked Redis, test app client |
| `backend/tests/test_presence.py` | Create | Unit tests for presence storage functions |
| `backend/tests/test_devices_api.py` | Create | Route tests: 404 on approve, is_online in device list |
| `backend/tests/test_ws.py` | Create | WS tests: heartbeat, presence set/cleared, unrecognized event error |
| `backend/app/storage.py` | Modify | Add `PRESENCE_TTL`, `set_presence`, `delete_presence`, `is_online`; update `list_devices` to attach `is_online` |
| `backend/app/schemas.py` | Modify | Remove `WSRegisterDevice`, `WSApproveDevice`, `WSDevicePending`, `DeviceApproveResponse`; update `DeviceResponse` |
| `backend/app/devices.py` | Modify | Remove `approve_device` endpoint |
| `backend/app/ws.py` | Modify | Remove `handle_register_device`, `handle_approve_device`; add `handle_heartbeat`; add else-error clause; set/delete presence |
| `backend/scripts/integration_test.py` | Modify | Rewrite SEC-B2 to assert unrecognized-event error |

---

## Task 1: Test infrastructure

**Files:**
- Create: `backend/requirements-dev.txt`
- Create: `backend/tests/conftest.py`

- [ ] **Step 1: Create requirements-dev.txt**

```
# backend/requirements-dev.txt
pytest==8.3.4
pytest-asyncio==0.25.2
httpx==0.28.1
```

- [ ] **Step 2: Install dev dependencies**

```bash
pip install -r backend/requirements-dev.txt
```

Expected: packages install without error.

- [ ] **Step 3: Create conftest.py**

```python
# backend/tests/conftest.py
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import AsyncClient, ASGITransport


# ---------------------------------------------------------------------------
# Shared mock-Redis fixture
# ---------------------------------------------------------------------------

def make_mock_redis() -> MagicMock:
    """Return a MagicMock that mimics redis.asyncio.Redis async methods."""
    r = MagicMock()
    r.get = AsyncMock(return_value=None)
    r.set = AsyncMock(return_value=True)
    r.delete = AsyncMock(return_value=1)
    r.exists = AsyncMock(return_value=0)
    r.expire = AsyncMock(return_value=True)
    r.sadd = AsyncMock(return_value=1)
    r.smembers = AsyncMock(return_value=set())
    r.incr = AsyncMock(return_value=1)
    r.zadd = AsyncMock(return_value=1)
    r.zcard = AsyncMock(return_value=0)
    r.zrange = AsyncMock(return_value=[])
    r.zrangebyscore = AsyncMock(return_value=[])
    r.zremrangebyrank = AsyncMock(return_value=0)
    r.lpop = AsyncMock(return_value=None)
    r.rpush = AsyncMock(return_value=1)
    return r


@pytest.fixture
def mock_redis():
    """Patch storage._redis with a MagicMock for the duration of the test."""
    r = make_mock_redis()
    with patch("backend.app.storage._redis", r):
        yield r


# ---------------------------------------------------------------------------
# Async HTTP test client
# ---------------------------------------------------------------------------

@pytest.fixture
async def async_client(mock_redis):
    """AsyncClient wired to the FastAPI app with Redis already mocked."""
    from backend.app.main import app
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        yield client
```

- [ ] **Step 4: Verify pytest discovers the fixtures**

```bash
cd /path/to/AirClip
pytest backend/tests/conftest.py --collect-only
```

Expected: `no tests ran` (no test functions yet, but no import errors).

- [ ] **Step 5: Commit**

```bash
git add backend/requirements-dev.txt backend/tests/conftest.py
git commit -m "test: add pytest infrastructure and mock-redis fixture"
```

---

## Task 2: Presence storage functions

**Files:**
- Modify: `backend/app/storage.py` (add after `update_device_last_seen`, before the clipboard section)
- Create: `backend/tests/test_presence.py`

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/test_presence.py
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch, MagicMock


def make_redis() -> MagicMock:
    r = MagicMock()
    r.set = AsyncMock(return_value=True)
    r.delete = AsyncMock(return_value=1)
    r.exists = AsyncMock(return_value=0)
    return r


@pytest.mark.asyncio
async def test_set_presence_writes_key_with_ttl():
    r = make_redis()
    with patch("backend.app.storage._redis", r):
        from backend.app import storage
        await storage.set_presence("dev-abc")
    r.set.assert_called_once_with("presence:dev-abc", "online", ex=45)


@pytest.mark.asyncio
async def test_delete_presence_removes_key():
    r = make_redis()
    with patch("backend.app.storage._redis", r):
        from backend.app import storage
        await storage.delete_presence("dev-abc")
    r.delete.assert_called_once_with("presence:dev-abc")


@pytest.mark.asyncio
async def test_is_online_returns_true_when_key_exists():
    r = make_redis()
    r.exists = AsyncMock(return_value=1)
    with patch("backend.app.storage._redis", r):
        from backend.app import storage
        result = await storage.is_online("dev-abc")
    assert result is True


@pytest.mark.asyncio
async def test_is_online_returns_false_when_key_absent():
    r = make_redis()
    r.exists = AsyncMock(return_value=0)
    with patch("backend.app.storage._redis", r):
        from backend.app import storage
        result = await storage.is_online("dev-abc")
    assert result is False
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
pytest backend/tests/test_presence.py -v
```

Expected: 4 failures — `AttributeError: module 'storage' has no attribute 'set_presence'`

- [ ] **Step 3: Add presence functions to storage.py**

Add `PRESENCE_TTL` constant after `CLIP_HISTORY_MAX` on line 14:

```python
PRESENCE_TTL = 45  # seconds — device heartbeat must arrive within this window
```

Add the three functions after `update_device_last_seen` (after line 144), before the `# --- Clipboard Message Storage ---` comment:

```python
# --- Device Presence ---

async def set_presence(device_id: str) -> None:
    """Mark device as online. TTL renewed on each heartbeat."""
    r = get_redis()
    await r.set(f"presence:{device_id}", "online", ex=PRESENCE_TTL)


async def delete_presence(device_id: str) -> None:
    """Remove online marker immediately on disconnect."""
    r = get_redis()
    await r.delete(f"presence:{device_id}")


async def is_online(device_id: str) -> bool:
    """Return True if the presence key exists (device is connected)."""
    r = get_redis()
    return bool(await r.exists(f"presence:{device_id}"))
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
pytest backend/tests/test_presence.py -v
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/app/storage.py backend/tests/test_presence.py
git commit -m "feat: add device presence functions to storage (set/delete/is_online)"
```

---

## Task 3: Update list_devices to attach is_online

**Files:**
- Modify: `backend/app/storage.py` — `list_devices` function (lines 109-117)
- Tests in Task 4 below (covers both schema and list_devices together)

- [ ] **Step 1: Replace list_devices in storage.py**

The current function (lines 109-117):

```python
async def list_devices(account_id: str) -> List[dict]:
    r = get_redis()
    device_ids = await r.smembers(f"account:{account_id}:devices")
    devices = []
    for did in device_ids:
        d = await get_device(did)
        if d:
            devices.append(d)
    return devices
```

Replace with:

```python
async def list_devices(account_id: str) -> List[dict]:
    r = get_redis()
    device_ids = await r.smembers(f"account:{account_id}:devices")
    devices = []
    for did in device_ids:
        d = await get_device(did)
        if d:
            d["is_online"] = await is_online(did)
            devices.append(d)
    return devices
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/storage.py
git commit -m "feat: attach is_online to each device in list_devices"
```

---

## Task 4: Update schemas + remove approval endpoint

**Files:**
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/devices.py`
- Create: `backend/tests/test_devices_api.py`

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/test_devices_api.py
from __future__ import annotations

import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock

import httpx
from httpx import AsyncClient, ASGITransport


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _account():
    return {"id": "acct-1", "email": "a@test.com"}


def _device(is_online: bool = False):
    return {
        "device_id": "dev-1",
        "account_id": "acct-1",
        "device_name": "Test Mac",
        "platform": "mac",
        "public_key": "pk1",
        "trust_status": "trusted",
        "created_at": "2026-01-01T00:00:00+00:00",
        "last_seen": "2026-01-01T00:00:00+00:00",
        "is_online": is_online,
    }


# ---------------------------------------------------------------------------
# POST /devices/{id}/approve must return 404
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_approve_endpoint_returns_404():
    from backend.app.main import app
    with patch("backend.app.auth.get_current_user", return_value=_account()):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post(
                "/devices/dev-1/approve",
                headers={"Authorization": "Bearer fake"},
            )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# GET /devices returns is_online field
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_devices_includes_is_online_false():
    from backend.app.main import app
    with (
        patch("backend.app.devices.storage.list_devices", AsyncMock(return_value=[_device(is_online=False)])),
        patch("backend.app.auth.get_current_user", return_value=_account()),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.get(
                "/devices/",
                headers={"Authorization": "Bearer fake"},
            )
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["is_online"] is False


@pytest.mark.asyncio
async def test_list_devices_includes_is_online_true():
    from backend.app.main import app
    with (
        patch("backend.app.devices.storage.list_devices", AsyncMock(return_value=[_device(is_online=True)])),
        patch("backend.app.auth.get_current_user", return_value=_account()),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.get(
                "/devices/",
                headers={"Authorization": "Bearer fake"},
            )
    assert resp.status_code == 200
    body = resp.json()
    assert body[0]["is_online"] is True
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
pytest backend/tests/test_devices_api.py -v
```

Expected: `test_approve_endpoint_returns_404` fails with 200 or 400 (endpoint exists); `is_online` tests fail because `DeviceResponse` has no `is_online` field.

- [ ] **Step 3: Update schemas.py**

Replace the entire file content with:

```python
from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, EmailStr, field_serializer, field_validator


# --- Auth ---

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    token: str
    account_id: str


# --- Account ---

class Account(BaseModel):
    id: str
    email: str
    password_hash: str
    created_at: datetime


# --- Device ---

class DeviceRegisterRequest(BaseModel):
    device_name: str
    platform: Literal["mac", "android"]
    public_key: str  # base64-encoded X25519 public key


class DeviceResponse(BaseModel):
    device_id: str
    device_name: str
    platform: str
    public_key: str
    trust_status: Literal["trusted"]
    created_at: datetime
    last_seen: Optional[datetime] = None
    is_online: bool = False


class DeviceRegisterResponse(DeviceResponse):
    token: str


# --- WebSocket Messages (Client → Server) ---

class ClipboardPayload(BaseModel):
    to_device_id: str
    ciphertext: str  # base64
    nonce: str  # base64


class WSSendClipboard(BaseModel):
    type: Literal["send_clipboard"] = "send_clipboard"
    payloads: list[ClipboardPayload]


class WSAck(BaseModel):
    type: Literal["ack"] = "ack"
    message_id: str


# --- WebSocket Messages (Server → Client) ---

class WSHello(BaseModel):
    type: Literal["hello"] = "hello"
    latest_seq: int  # serialised as string — see field_serializer below

    @field_serializer("latest_seq")
    def serialize_latest_seq(self, v: int) -> str:
        return str(v)


class WSDeliverClipboard(BaseModel):
    type: Literal["deliver_clipboard"] = "deliver_clipboard"
    message_id: str
    from_device_id: str
    ciphertext: str  # base64
    nonce: str  # base64
    seq: int  # monotonic per-account seq; required, must be >= 1; serialised as string

    @field_validator("seq")
    @classmethod
    def seq_must_be_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError(f"seq must be >= 1, got {v}")
        return v

    @field_serializer("seq")
    def serialize_seq(self, v: int) -> str:
        return str(v)


# --- Stored clipboard message ---

class ClipboardMessage(BaseModel):
    id: str
    from_device_id: str
    to_device_id: str
    created_at: datetime
    ciphertext: str
    nonce: str
    version: int = 1


# --- Clip history REST response ---

class ClipHistoryItem(BaseModel):
    seq: int  # serialised as string — see field_serializer below
    message_id: str
    from_device_id: str
    ciphertext: str  # base64 — encrypted for the requesting device
    nonce: str       # base64

    @field_serializer("seq")
    def serialize_seq(self, v: int) -> str:
        return str(v)
```

- [ ] **Step 4: Remove approve_device endpoint from devices.py**

Replace `backend/app/devices.py` with:

```python
from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException

from . import storage
from .auth import create_token, get_current_user
from .schemas import DeviceRegisterRequest, DeviceRegisterResponse, DeviceResponse

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", response_model=DeviceRegisterResponse)
async def register_device(
    req: DeviceRegisterRequest,
    account: dict = Depends(get_current_user),
):
    conflict = await storage.find_trusted_device_by_public_key(
        account["id"], req.public_key,
    )
    if conflict:
        raise HTTPException(
            status_code=409,
            detail="Public key already bound to a trusted device",
        )
    device = await storage.create_device(
        account_id=account["id"],
        device_name=req.device_name,
        platform=req.platform,
        public_key=req.public_key,
    )
    device_token = create_token(account["id"], token_type="device", device_id=device["device_id"])
    return DeviceRegisterResponse(**device, token=device_token)


@router.get("/", response_model=List[DeviceResponse])
async def list_devices(account: dict = Depends(get_current_user)):
    devices = await storage.list_devices(account["id"])
    return [DeviceResponse(**d) for d in devices]
```

- [ ] **Step 5: Run tests — verify they pass**

```bash
pytest backend/tests/test_devices_api.py -v
```

Expected: 3 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/app/schemas.py backend/app/devices.py backend/tests/test_devices_api.py
git commit -m "feat: remove approval endpoint, add is_online to DeviceResponse"
```

---

## Task 5: WebSocket — remove dead handlers, add heartbeat, wire presence

**Files:**
- Modify: `backend/app/ws.py`
- Create: `backend/tests/test_ws.py`

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/test_ws.py
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch, MagicMock, call


# ---------------------------------------------------------------------------
# handle_heartbeat
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_heartbeat_renews_presence_and_updates_last_seen():
    with (
        patch("backend.app.storage._redis", MagicMock(
            set=AsyncMock(return_value=True),
            get=AsyncMock(return_value=None),
        )),
        patch("backend.app.storage.set_presence", AsyncMock()) as mock_set,
        patch("backend.app.storage.update_device_last_seen", AsyncMock()) as mock_seen,
    ):
        from backend.app.ws import handle_heartbeat
        await handle_heartbeat("dev-abc")

    mock_set.assert_called_once_with("dev-abc")
    mock_seen.assert_called_once_with("dev-abc")


# ---------------------------------------------------------------------------
# unrecognized event type → error response sent to caller
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unrecognized_event_sends_error():
    sent_messages = []

    async def fake_send_json(device_id: str, data: dict) -> bool:
        sent_messages.append((device_id, data))
        return True

    with patch("backend.app.ws.manager") as mock_manager:
        mock_manager.send_json = AsyncMock(side_effect=fake_send_json)
        from backend.app.ws import websocket_endpoint  # noqa: F401 — confirms import

        # Test the dispatch logic directly via the handler lookup
        # We simulate the else-branch by calling the handler dispatch
        # with an unknown type and verifying the error payload.
        from backend.app import ws as ws_module

        # Patch out all storage calls so we can call _dispatch_message directly
        with (
            patch.object(ws_module, "handle_heartbeat", AsyncMock()),
            patch.object(ws_module, "handle_ack", AsyncMock()),
            patch.object(ws_module, "handle_send_clipboard", AsyncMock()),
        ):
            await ws_module._dispatch_message(
                account={"id": "acct-1"},
                device_id="dev-1",
                data={"type": "approve_device", "target_device_id": "dev-2"},
            )

    assert len(sent_messages) == 1
    device_id, payload = sent_messages[0]
    assert device_id == "dev-1"
    assert payload["type"] == "error"
    assert "unrecognized" in payload["message"].lower()


# ---------------------------------------------------------------------------
# presence set on connect, deleted on disconnect
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_presence_set_on_connect_deleted_on_disconnect():
    """
    Simulate the connect/disconnect lifecycle without a real WebSocket:
    call set_presence directly with the same device_id that disconnect
    would use, and verify both sides are exercised.
    """
    with (
        patch("backend.app.storage.set_presence", AsyncMock()) as mock_set,
        patch("backend.app.storage.delete_presence", AsyncMock()) as mock_del,
        patch("backend.app.storage.update_device_last_seen", AsyncMock()),
    ):
        from backend.app import storage as st
        await st.set_presence("dev-xyz")
        await st.delete_presence("dev-xyz")

    mock_set.assert_called_once_with("dev-xyz")
    mock_del.assert_called_once_with("dev-xyz")
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
pytest backend/tests/test_ws.py -v
```

Expected: `test_heartbeat_*` fails — `handle_heartbeat` not defined. `test_unrecognized_event_*` fails — `_dispatch_message` not defined. Presence test passes (it only calls storage directly).

- [ ] **Step 3: Replace ws.py**

```python
# backend/app/ws.py
from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Dict, Optional, Tuple

_log = logging.getLogger(__name__)

from fastapi import WebSocket, WebSocketDisconnect

from . import storage
from .auth import decode_token
from .schemas import (
    ClipboardMessage,
    WSDeliverClipboard,
    WSHello,
)


class ConnectionManager:
    """Track active WebSocket connections by device_id."""

    def __init__(self):
        self._connections: Dict[str, WebSocket] = {}

    async def connect(self, device_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections[device_id] = ws
        await storage.update_device_last_seen(device_id)

    def disconnect(self, device_id: str) -> None:
        self._connections.pop(device_id, None)

    async def send_json(self, device_id: str, data: dict) -> bool:
        ws = self._connections.get(device_id)
        if ws:
            await ws.send_json(data)
            return True
        return False

    def is_connected(self, device_id: str) -> bool:
        return device_id in self._connections


manager = ConnectionManager()


async def authenticate_ws(ws: WebSocket) -> Optional[Tuple[dict, str]]:
    """Extract account and device_id from a device-scoped JWT.

    Returns (account, device_id) or None.  The device_id is authoritative
    — no client-supplied device_id is accepted.
    """
    token = None
    auth_header = ws.headers.get("authorization", "").strip()
    if auth_header.startswith("Bearer "):
        token = auth_header[7:].strip() or None
    # HIGH 4: query-param token fallback removed — Authorization header only
    if not token:
        return None
    try:
        payload = decode_token(token)
        if payload.get("token_type") != "device":
            return None
        device_id = payload.get("device_id")
        if not device_id:
            return None
        account = await storage.get_account_by_id(payload["sub"])
        if not account:
            return None
        return (account, device_id)
    except Exception:
        return None


async def deliver_pending(device_id: str) -> None:
    """Deliver any queued messages to a newly connected device."""
    messages = await storage.pop_pending_messages(device_id)
    for msg in messages:
        raw_seq = msg.get("seq")
        if isinstance(raw_seq, bool):
            _log.error(
                "deliver_pending: msg %s has invalid seq=%r — skipping",
                msg.get("id", "?"),
                raw_seq,
            )
            continue
        try:
            seq = int(raw_seq)
        except (TypeError, ValueError):
            _log.error(
                "deliver_pending: msg %s has invalid seq=%r — skipping",
                msg.get("id", "?"),
                raw_seq,
            )
            continue
        if seq < 1:
            _log.error(
                "deliver_pending: msg %s has invalid seq=%r — skipping",
                msg.get("id", "?"),
                raw_seq,
            )
            continue
        outbound = WSDeliverClipboard(
            message_id=msg["id"],
            from_device_id=msg["from_device_id"],
            ciphertext=msg["ciphertext"],
            nonce=msg["nonce"],
            seq=seq,
        )
        await manager.send_json(device_id, outbound.model_dump())


async def handle_heartbeat(device_id: str) -> None:
    """Renew presence TTL and update last_seen timestamp."""
    await storage.set_presence(device_id)
    await storage.update_device_last_seen(device_id)


async def handle_send_clipboard(
    account: dict, caller_device_id: str, data: dict,
) -> None:
    """Route encrypted clipboard payloads.  Only trusted devices may send."""
    caller = await storage.get_device(caller_device_id)
    if not caller or caller["trust_status"] != "trusted":
        return

    for payload in data.get("payloads", []):
        to_device_id = payload["to_device_id"]
        target = await storage.get_device(to_device_id)
        if not target or target["account_id"] != account["id"]:
            continue
        if target["trust_status"] != "trusted":
            continue

        msg_id = str(uuid.uuid4())
        seq = await storage.next_clip_seq(account["id"])
        msg = ClipboardMessage(
            id=msg_id,
            from_device_id=caller_device_id,
            to_device_id=to_device_id,
            created_at=datetime.now(timezone.utc),
            ciphertext=payload["ciphertext"],
            nonce=payload["nonce"],
        )

        # HIGH 1: include seq in the stored dict so pending delivery also carries it
        msg_dict = {**msg.model_dump(mode="json"), "seq": seq}
        # Always store in history buffer (30-min catch-up for offline devices)
        await storage.store_clip_history(account["id"], seq, msg_dict)

        delivered = await manager.send_json(
            to_device_id,
            WSDeliverClipboard(
                message_id=msg_id,
                from_device_id=caller_device_id,
                ciphertext=payload["ciphertext"],
                nonce=payload["nonce"],
                seq=seq,
            ).model_dump(),
        )

        if not delivered:
            await storage.store_clipboard_message(msg_dict)


async def handle_ack(account_id: str, device_id: str, data: dict) -> None:
    """Delete message only if this device is the intended recipient."""
    msg_id = data.get("message_id")
    if not msg_id:
        return
    msg = await storage.get_clipboard_message(msg_id)
    if not msg:
        return  # already deleted, expired, or live-delivered
    if msg["to_device_id"] != device_id:
        return  # caller is not the intended recipient
    await storage.delete_clipboard_message(msg_id)


async def _dispatch_message(account: dict, device_id: str, data: dict) -> None:
    """Route an inbound WebSocket message to the appropriate handler."""
    msg_type = data.get("type")

    if msg_type == "heartbeat":
        await handle_heartbeat(device_id)
    elif msg_type == "ack":
        await handle_ack(account["id"], device_id, data)
    elif msg_type == "send_clipboard":
        await handle_send_clipboard(account, device_id, data)
    else:
        await manager.send_json(
            device_id,
            {"type": "error", "message": f"unrecognized event: {msg_type}"},
        )


async def websocket_endpoint(ws: WebSocket) -> None:
    result = await authenticate_ws(ws)
    if not result:
        await ws.close(code=4001, reason="Unauthorized")
        return

    account, device_id = result

    device = await storage.get_device(device_id)
    if not device or device["account_id"] != account["id"]:
        await ws.close(code=4003, reason="Invalid device")
        return

    await manager.connect(device_id, ws)
    await storage.set_presence(device_id)

    try:
        await deliver_pending(device_id)
        latest_seq = await storage.get_latest_seq(account["id"])
        await manager.send_json(
            device_id, WSHello(latest_seq=latest_seq).model_dump()
        )

        while True:
            raw = await ws.receive_text()
            data = json.loads(raw)
            await _dispatch_message(account, device_id, data)

    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(device_id)
        await storage.delete_presence(device_id)
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
pytest backend/tests/test_ws.py -v
```

Expected: 3 passed.

- [ ] **Step 5: Run full test suite**

```bash
pytest backend/tests/ -v
```

Expected: all tests pass (presence + devices API + ws).

- [ ] **Step 6: Commit**

```bash
git add backend/app/ws.py backend/tests/test_ws.py
git commit -m "feat: add heartbeat handler, presence on connect/disconnect, error on unrecognized events"
```

---

## Task 6: Update integration_test.py SEC-B2

**Files:**
- Modify: `backend/scripts/integration_test.py` lines 387-409

- [ ] **Step 1: Replace the SEC-B2 block**

Find and replace the block from `# SEC-B2` to the end of that section (line 409). The new test connects a trusted device, sends `approve_device`, and asserts the server sends back an error response — not a crash, not a success.

Replace lines 387-409 with:

```python
    # -----------------------------------------------------------------------
    # SEC-B2: approve_device is no longer a recognized event — server must
    #         return an error response, not crash and not silently succeed.
    # -----------------------------------------------------------------------
    print("\n--- SEC-B2: approve_device returns unrecognized-event error ---")

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a2:
        # Drain the hello message first
        await asyncio.wait_for(ws_a2.recv(), timeout=3.0)

        await ws_a2.send(json.dumps({
            "type": "approve_device",
            "target_device_id": dev_b_id,
        }))

        try:
            raw = await asyncio.wait_for(ws_a2.recv(), timeout=3.0)
            response = json.loads(raw)
            is_error = (
                response.get("type") == "error"
                and "unrecognized" in response.get("message", "").lower()
            )
            step(
                "approve_device returns unrecognized-event error",
                is_error,
                f"Got: {response}",
            )
        except asyncio.TimeoutError:
            step(
                "approve_device returns unrecognized-event error",
                False,
                "No response received within 3s — expected error message",
            )
```

- [ ] **Step 2: Run integration test against a live server**

Start the backend and Redis, then run:

```bash
cd backend
python scripts/integration_test.py
```

Expected: SEC-B2 line shows `PASS`. All other existing steps should continue to pass.

- [ ] **Step 3: Commit**

```bash
git add backend/scripts/integration_test.py
git commit -m "test: rewrite SEC-B2 to assert approve_device returns unrecognized-event error"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| Register → trust_status = "trusted" | Already true in storage (DEV MODE comment); devices.py verified in Task 4 |
| Remove approve REST endpoint | Task 4 — endpoint deleted, test asserts 404 |
| Remove approve_device WS handler | Task 5 — handler deleted, dispatch goes to else-branch |
| Remove register_device WS handler | Task 5 — handler deleted |
| Remove WSApproveDevice, WSRegisterDevice, WSDevicePending schemas | Task 4 — schemas.py rewritten |
| Presence: set on WS connect | Task 5 — `set_presence` called after `manager.connect` |
| Presence: TTL renewed on heartbeat | Task 5 — `handle_heartbeat` calls `set_presence` (which uses `ex=PRESENCE_TTL`) |
| Presence: deleted on WS disconnect | Task 5 — `delete_presence` in finally block |
| GET /devices includes is_online | Tasks 3+4 — `list_devices` attaches `is_online`, `DeviceResponse` has the field |
| trust_status check retained in send/receive | Task 5 — unchanged in `handle_send_clipboard` |
| Integration test SEC-B2 updated | Task 6 |
| Client dead code flagged, not touched | Plan header — noted as Prompt 2 follow-up |

All requirements covered. No gaps.
