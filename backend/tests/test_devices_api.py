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
