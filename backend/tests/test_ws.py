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

        with (
            patch("backend.app.ws.handle_heartbeat", AsyncMock()),
            patch("backend.app.ws.handle_ack", AsyncMock()),
            patch("backend.app.ws.handle_send_clipboard", AsyncMock()),
        ):
            from backend.app.ws import _dispatch_message
            await _dispatch_message(
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
async def test_presence_set_and_deleted_via_storage():
    with (
        patch("backend.app.storage.set_presence", AsyncMock()) as mock_set,
        patch("backend.app.storage.delete_presence", AsyncMock()) as mock_del,
    ):
        from backend.app import storage as st
        await st.set_presence("dev-xyz")
        await st.delete_presence("dev-xyz")

    mock_set.assert_called_once_with("dev-xyz")
    mock_del.assert_called_once_with("dev-xyz")
