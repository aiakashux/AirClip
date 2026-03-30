from __future__ import annotations

import json
import secrets
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

from redis.asyncio import Redis

CLIPBOARD_TTL = 60  # seconds

CLIP_HISTORY_TTL = 30 * 60  # 30 minutes
CLIP_HISTORY_MAX = 20       # max entries per account (30-min window)

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
    trust_status = "trusted"  # DEV MODE: auto-trust devices
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


# --- Clipboard History (catch-up buffer) ---

async def next_clip_seq(account_id: str) -> int:
    """Increment and return the per-account monotonic clip sequence number."""
    r = get_redis()
    return int(await r.incr(f"clips:seq:{account_id}"))


async def get_epoch(account_id: str) -> str:
    """Return the stable catch-up epoch for this account.

    Created once via SETNX (no TTL) so it survives restarts.
    Disappears only on a full Redis flush; clients detect the change and reset
    their last_seen_seq to 0 so catch-up restarts cleanly.
    """
    r = get_redis()
    epoch_key = f"clips:epoch:{account_id}"
    epoch = await r.get(epoch_key)
    if not epoch:
        candidate = secrets.token_hex(8)
        await r.set(epoch_key, candidate, nx=True)
        epoch = await r.get(epoch_key)  # read back the winner (nx=True is atomic)
    return epoch  # type: ignore[return-value]


async def store_clip_history(account_id: str, seq: int, msg: dict) -> None:
    """
    Store a clip in the per-account history for 30 min.
    Uses a single sorted set keyed by account_id with seq as score.
    The clip payload carries to_device_id so the REST endpoint can filter per device.
    Trims to CLIP_HISTORY_MAX entries per account after insert.
    """
    r = get_redis()
    hist_key = f"clips:hist:{account_id}"
    clip_key = f"clip:{account_id}:{seq}"

    await r.set(clip_key, json.dumps({**msg, "seq": seq}), ex=CLIP_HISTORY_TTL)
    await r.zadd(hist_key, {str(seq): seq})
    await r.expire(hist_key, CLIP_HISTORY_TTL)

    # Trim oldest entries beyond the per-account cap
    count = await r.zcard(hist_key)
    if count > CLIP_HISTORY_MAX:
        excess = count - CLIP_HISTORY_MAX
        old_seqs = await r.zrange(hist_key, 0, excess - 1)
        if old_seqs:
            await r.delete(*[f"clip:{account_id}:{s}" for s in old_seqs])
            await r.zremrangebyrank(hist_key, 0, excess - 1)


async def get_latest_seq(account_id: str) -> int:
    """Return the highest seq stored for this account, or 0 if none."""
    r = get_redis()
    result = await r.zrange(f"clips:hist:{account_id}", -1, -1, withscores=True)
    if result:
        return int(result[0][1])
    return 0


async def get_clip_history(
    account_id: str, device_id: str, after_seq: int, limit: int
) -> List[dict]:
    """Return up to [limit] clips with seq > after_seq addressed to device_id, ascending.

    Uses the per-account sorted set and filters by to_device_id in Python.
    The full set is bounded by CLIP_HISTORY_MAX so scanning is O(CLIP_HISTORY_MAX).
    """
    r = get_redis()
    hist_key = f"clips:hist:{account_id}"
    # Fetch all seqs after after_seq (bounded by CLIP_HISTORY_MAX=100)
    all_seq_strs = await r.zrangebyscore(hist_key, after_seq + 1, "+inf")
    clips: List[dict] = []
    for seq_str in all_seq_strs:
        if len(clips) >= limit:
            break
        data = await r.get(f"clip:{account_id}:{seq_str}")
        if data:
            clip = json.loads(data)
            if clip.get("to_device_id") == device_id:
                clips.append(clip)
    return clips
