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
