from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

from redis.asyncio import Redis

CLIPBOARD_TTL = 60  # seconds

_redis: Optional[Redis] = None


async def init_redis(url: str = "redis://localhost:6379") -> Redis:
    global _redis
    _redis = Redis.from_url(url, decode_responses=True)
    await _redis.ping()
    return _redis


async def close_redis() -> None:
    global _redis
    if _redis:
        await _redis.aclose()
        _redis = None


def get_redis() -> Redis:
    assert _redis is not None, "Redis not initialized"
    return _redis


# --- Account CRUD ---

async def create_account(email: str, password_hash: str) -> dict:
    r = get_redis()
    existing = await r.get(f"account:email:{email}")
    if existing:
        return None
    account_id = str(uuid.uuid4())
    account = {
        "id": account_id,
        "email": email,
        "password_hash": password_hash,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await r.set(f"account:{account_id}", json.dumps(account))
    await r.set(f"account:email:{email}", account_id)
    return account


async def get_account_by_email(email: str) -> Optional[dict]:
    r = get_redis()
    account_id = await r.get(f"account:email:{email}")
    if not account_id:
        return None
    return await get_account_by_id(account_id)


async def get_account_by_id(account_id: str) -> Optional[dict]:
    r = get_redis()
    data = await r.get(f"account:{account_id}")
    if not data:
        return None
    return json.loads(data)


# --- Device CRUD ---

async def create_device(
    account_id: str,
    device_name: str,
    platform: str,
    public_key: str,
) -> dict:
    r = get_redis()
    device_id = str(uuid.uuid4())
    devices = await list_devices(account_id)
    trust_status = "trusted" if len(devices) == 0 else "pending"
    now = datetime.now(timezone.utc).isoformat()
    device = {
        "device_id": device_id,
        "account_id": account_id,
        "device_name": device_name,
        "platform": platform,
        "public_key": public_key,
        "trust_status": trust_status,
        "created_at": now,
        "last_seen": now,
    }
    await r.set(f"device:{device_id}", json.dumps(device))
    await r.sadd(f"account:{account_id}:devices", device_id)
    return device


async def get_device(device_id: str) -> Optional[dict]:
    r = get_redis()
    data = await r.get(f"device:{device_id}")
    if not data:
        return None
    return json.loads(data)


async def list_devices(account_id: str) -> List[dict]:
    r = get_redis()
    device_ids = await r.smembers(f"account:{account_id}:devices")
    devices = []
    for did in device_ids:
        d = await get_device(did)
        if d:
            devices.append(d)
    return devices


async def find_trusted_device_by_public_key(account_id: str, public_key: str) -> Optional[dict]:
    """Return a trusted device using this public_key, or None."""
    devices = await list_devices(account_id)
    for d in devices:
        if d["public_key"] == public_key and d["trust_status"] == "trusted":
            return d
    return None


async def update_device_trust(device_id: str, trust_status: str) -> Optional[dict]:
    device = await get_device(device_id)
    if not device:
        return None
    device["trust_status"] = trust_status
    r = get_redis()
    await r.set(f"device:{device_id}", json.dumps(device))
    return device


async def update_device_last_seen(device_id: str) -> None:
    device = await get_device(device_id)
    if device:
        device["last_seen"] = datetime.now(timezone.utc).isoformat()
        r = get_redis()
        await r.set(f"device:{device_id}", json.dumps(device))


# --- Clipboard Message Storage ---

async def store_clipboard_message(msg: dict) -> None:
    r = get_redis()
    msg_id = msg["id"]
    to_device = msg["to_device_id"]
    await r.set(f"msg:{msg_id}", json.dumps(msg), ex=CLIPBOARD_TTL)
    await r.rpush(f"pending:{to_device}", msg_id)
    await r.expire(f"pending:{to_device}", CLIPBOARD_TTL)


async def get_clipboard_message(msg_id: str) -> Optional[dict]:
    r = get_redis()
    data = await r.get(f"msg:{msg_id}")
    if not data:
        return None
    return json.loads(data)


async def delete_clipboard_message(msg_id: str) -> None:
    r = get_redis()
    await r.delete(f"msg:{msg_id}")


async def pop_pending_messages(device_id: str) -> List[dict]:
    r = get_redis()
    messages = []
    while True:
        msg_id = await r.lpop(f"pending:{device_id}")
        if not msg_id:
            break
        msg = await get_clipboard_message(msg_id)
        if msg:
            messages.append(msg)
    return messages
