# backend/tests/test_presence.py
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest


@pytest.mark.asyncio
async def test_connection_manager_accepts_and_marks_last_seen():
    from backend.app.ws import ConnectionManager

    manager = ConnectionManager()
    ws = AsyncMock()

    with patch("backend.app.storage.update_device_last_seen", AsyncMock()) as mock_seen:
        await manager.connect("dev-abc", ws)

    ws.accept.assert_awaited_once()
    mock_seen.assert_awaited_once_with("dev-abc")
    assert manager.is_connected("dev-abc") is True


@pytest.mark.asyncio
async def test_connection_manager_disconnect_forgets_device():
    from backend.app.ws import ConnectionManager

    manager = ConnectionManager()
    ws = AsyncMock()

    with patch("backend.app.storage.update_device_last_seen", AsyncMock()):
        await manager.connect("dev-abc", ws)

    manager.disconnect("dev-abc")

    assert manager.is_connected("dev-abc") is False


@pytest.mark.asyncio
async def test_connection_manager_send_json_returns_false_when_offline():
    from backend.app.ws import ConnectionManager

    manager = ConnectionManager()

    sent = await manager.send_json("missing-device", {"type": "hello"})

    assert sent is False


@pytest.mark.asyncio
async def test_connection_manager_send_json_sends_to_connected_device():
    from backend.app.ws import ConnectionManager

    manager = ConnectionManager()
    ws = AsyncMock()

    with patch("backend.app.storage.update_device_last_seen", AsyncMock()):
        await manager.connect("dev-abc", ws)

    sent = await manager.send_json("dev-abc", {"type": "hello"})

    assert sent is True
    ws.send_json.assert_awaited_once_with({"type": "hello"})
