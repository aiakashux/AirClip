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
