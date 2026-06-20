from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import List, Optional

import aiosqlite

_DB_PATH = "airclip.db"
_db: Optional[aiosqlite.Connection] = None

VALID_HISTORY_DAYS = {7, 30, 90}

_DEFAULT_SETTINGS = {
    "sync_enabled": True,
    "history_days": 30,
    "encryption_enabled": True,
    "shortcuts": {"open_airclip": "cmd+shift+v", "paste_last": "cmd+shift+p"},
}


# --- Init / teardown ---

async def init_db(path: str = "airclip.db") -> None:
    global _DB_PATH, _db
    _DB_PATH = path
    _db = await aiosqlite.connect(path)
    _db.row_factory = aiosqlite.Row
    await _db.execute("PRAGMA journal_mode=WAL")
    await _db.execute("PRAGMA foreign_keys=ON")
    await _create_tables()


async def close_db() -> None:
    global _db
    if _db:
        await _db.close()
        _db = None


def get_db() -> aiosqlite.Connection:
    assert _db is not None, "DB not initialized"
    return _db


async def _create_tables() -> None:
    db = get_db()
    await db.executescript("""
        CREATE TABLE IF NOT EXISTS accounts (
            id          TEXT PRIMARY KEY,
            email       TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            settings    TEXT NOT NULL DEFAULT '{}',
            created_at  TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS devices (
            device_id   TEXT PRIMARY KEY,
            account_id  TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
            device_name TEXT NOT NULL,
            platform    TEXT NOT NULL,
            public_key  TEXT NOT NULL,
            trust_status TEXT NOT NULL DEFAULT 'trusted',
            created_at  TEXT NOT NULL,
            last_seen   TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_devices_account ON devices(account_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_pubkey ON devices(account_id, public_key);
    """)
    await db.commit()


# --- Account CRUD ---

async def create_account(email: str, password_hash: str) -> Optional[dict]:
    db = get_db()
    account_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    try:
        await db.execute(
            "INSERT INTO accounts (id, email, password_hash, settings, created_at) VALUES (?, ?, ?, ?, ?)",
            (account_id, email, password_hash, "{}", now),
        )
        await db.commit()
    except aiosqlite.IntegrityError:
        return None
    return {"id": account_id, "email": email, "password_hash": password_hash, "created_at": now}


async def get_account_by_email(email: str) -> Optional[dict]:
    db = get_db()
    async with db.execute("SELECT * FROM accounts WHERE email = ?", (email,)) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def get_account_by_id(account_id: str) -> Optional[dict]:
    db = get_db()
    async with db.execute("SELECT * FROM accounts WHERE id = ?", (account_id,)) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def update_account_email(account_id: str, new_email: str) -> Optional[dict]:
    db = get_db()
    try:
        await db.execute("UPDATE accounts SET email = ? WHERE id = ?", (new_email, account_id))
        await db.commit()
    except aiosqlite.IntegrityError:
        return None
    return await get_account_by_id(account_id)


async def update_account_password(account_id: str, new_password_hash: str) -> bool:
    db = get_db()
    await db.execute(
        "UPDATE accounts SET password_hash = ? WHERE id = ?", (new_password_hash, account_id)
    )
    await db.commit()
    return True


# --- Account settings ---

async def get_account_settings(account_id: str) -> dict:
    db = get_db()
    async with db.execute("SELECT settings FROM accounts WHERE id = ?", (account_id,)) as cur:
        row = await cur.fetchone()
    if not row:
        return dict(_DEFAULT_SETTINGS)
    stored = json.loads(row[0] or "{}")
    return {**_DEFAULT_SETTINGS, **stored}


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
    if "shortcuts" in patch and patch["shortcuts"] is not None:
        existing = settings.get("shortcuts", {})
        existing.update(patch["shortcuts"])
        settings["shortcuts"] = existing
    db = get_db()
    await db.execute(
        "UPDATE accounts SET settings = ? WHERE id = ?", (json.dumps(settings), account_id)
    )
    await db.commit()
    return settings


# --- Device CRUD ---

async def create_device(
    account_id: str,
    device_name: str,
    platform: str,
    public_key: str,
) -> dict:
    db = get_db()
    device_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    await db.execute(
        """INSERT INTO devices
           (device_id, account_id, device_name, platform, public_key, trust_status, created_at, last_seen)
           VALUES (?, ?, ?, ?, ?, 'trusted', ?, ?)""",
        (device_id, account_id, device_name, platform, public_key, now, now),
    )
    await db.commit()
    return {
        "device_id": device_id,
        "account_id": account_id,
        "device_name": device_name,
        "platform": platform,
        "public_key": public_key,
        "trust_status": "trusted",
        "created_at": now,
        "last_seen": now,
    }


async def get_device(device_id: str) -> Optional[dict]:
    db = get_db()
    async with db.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,)) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def list_devices(account_id: str) -> List[dict]:
    db = get_db()
    async with db.execute("SELECT * FROM devices WHERE account_id = ?", (account_id,)) as cur:
        rows = await cur.fetchall()
    return [dict(r) for r in rows]


async def find_trusted_device_by_public_key(account_id: str, public_key: str) -> Optional[dict]:
    db = get_db()
    async with db.execute(
        "SELECT * FROM devices WHERE account_id = ? AND public_key = ? AND trust_status = 'trusted'",
        (account_id, public_key),
    ) as cur:
        row = await cur.fetchone()
    return dict(row) if row else None


async def update_device_name(device_id: str, device_name: str) -> Optional[dict]:
    db = get_db()
    await db.execute(
        "UPDATE devices SET device_name = ? WHERE device_id = ?", (device_name, device_id)
    )
    await db.commit()
    return await get_device(device_id)


async def update_device_last_seen(device_id: str) -> None:
    db = get_db()
    now = datetime.now(timezone.utc).isoformat()
    await db.execute(
        "UPDATE devices SET last_seen = ? WHERE device_id = ?", (now, device_id)
    )
    await db.commit()


async def delete_device(account_id: str, device_id: str) -> bool:
    db = get_db()
    cur = await db.execute(
        "DELETE FROM devices WHERE device_id = ? AND account_id = ?",
        (device_id, account_id),
    )
    await db.commit()
    return cur.rowcount > 0
