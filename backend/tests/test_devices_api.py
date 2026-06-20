# backend/tests/test_devices_api.py
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch

from httpx import AsyncClient, ASGITransport


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


@pytest.mark.asyncio
async def test_register_device_returns_trusted_device_token():
    from backend.app.main import app
    from backend.app.auth import get_current_user

    created = _device()
    created.pop("is_online")

    app.dependency_overrides[get_current_user] = lambda: _account()
    try:
        with (
            patch("backend.app.devices.storage.find_trusted_device_by_public_key", AsyncMock(return_value=None)),
            patch("backend.app.devices.storage.create_device", AsyncMock(return_value=created)),
        ):
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                resp = await client.post(
                    "/devices/register",
                    json={
                        "device_name": "Test Mac",
                        "platform": "mac",
                        "public_key": "pk1",
                    },
                )

        assert resp.status_code == 200
        body = resp.json()
        assert body["device_id"] == "dev-1"
        assert body["trust_status"] == "trusted"
        assert body["token"]
    finally:
        app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# POST /devices/{id}/approve must return 404
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_approve_endpoint_returns_404():
    from backend.app.main import app
    from backend.app.auth import get_current_user

    app.dependency_overrides[get_current_user] = lambda: _account()
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post("/devices/dev-1/approve")
        assert resp.status_code == 404
    finally:
        app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# GET /devices returns is_online field
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_devices_includes_is_online_false():
    from backend.app.main import app
    from backend.app.auth import get_current_user

    app.dependency_overrides[get_current_user] = lambda: _account()
    try:
        with patch("backend.app.devices.storage.list_devices", AsyncMock(return_value=[_device(is_online=False)])):
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                resp = await client.get("/devices/")
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        assert body[0]["is_online"] is False
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_list_devices_includes_is_online_true():
    from backend.app.main import app
    from backend.app.auth import get_current_user

    app.dependency_overrides[get_current_user] = lambda: _account()
    try:
        with patch("backend.app.devices.storage.list_devices", AsyncMock(return_value=[_device(is_online=True)])):
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                resp = await client.get("/devices/")
        assert resp.status_code == 200
        body = resp.json()
        assert body[0]["is_online"] is True
    finally:
        app.dependency_overrides.clear()
