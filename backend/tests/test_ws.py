# backend/tests/test_ws.py
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest


@pytest.mark.asyncio
async def test_heartbeat_updates_last_seen_without_redis_presence():
    with patch("backend.app.storage.update_device_last_seen", AsyncMock()) as mock_seen:
        from backend.app.ws import _dispatch_message

        await _dispatch_message(
            account={"id": "acct-1"},
            device_id="dev-abc",
            data={"type": "heartbeat"},
        )

    mock_seen.assert_awaited_once_with("dev-abc")


@pytest.mark.asyncio
async def test_unrecognized_event_sends_error_to_caller():
    sent_messages = []

    async def fake_send_json(device_id: str, data: dict) -> bool:
        sent_messages.append((device_id, data))
        return True

    with patch("backend.app.ws.manager") as mock_manager:
        mock_manager.send_json = AsyncMock(side_effect=fake_send_json)

        from backend.app.ws import _dispatch_message

        await _dispatch_message(
            account={"id": "acct-1"},
            device_id="dev-1",
            data={"type": "approve_device", "target_device_id": "dev-2"},
        )

    assert sent_messages == [
        (
            "dev-1",
            {"type": "error", "message": "unrecognized event: approve_device"},
        )
    ]


@pytest.mark.asyncio
async def test_authenticate_ws_rejects_account_tokens():
    from backend.app.auth import create_token
    from backend.app.ws import authenticate_ws

    ws = AsyncMock()
    ws.headers = {"authorization": f"Bearer {create_token('acct-1', token_type='account')}"}

    result = await authenticate_ws(ws)

    assert result is None


@pytest.mark.asyncio
async def test_authenticate_ws_accepts_device_token_with_account():
    from backend.app.auth import create_token
    from backend.app.ws import authenticate_ws

    ws = AsyncMock()
    ws.headers = {
        "authorization": f"Bearer {create_token('acct-1', token_type='device', device_id='dev-1')}"
    }

    with patch(
        "backend.app.storage.get_account_by_id",
        AsyncMock(return_value={"id": "acct-1", "email": "a@test.com"}),
    ):
        result = await authenticate_ws(ws)

    assert result == ({"id": "acct-1", "email": "a@test.com"}, "dev-1")
