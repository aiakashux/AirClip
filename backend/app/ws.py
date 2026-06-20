from __future__ import annotations

import json
import logging
from typing import Dict, Optional, Tuple

_log = logging.getLogger(__name__)

from fastapi import WebSocket, WebSocketDisconnect

from . import storage
from .auth import decode_token


class ConnectionManager:
    """Track active WebSocket connections by device_id."""

    def __init__(self):
        self._connections: Dict[str, WebSocket] = {}

    async def connect(self, device_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections[device_id] = ws
        await storage.update_device_last_seen(device_id)

    def disconnect(self, device_id: str) -> None:
        self._connections.pop(device_id, None)

    async def send_json(self, device_id: str, data: dict) -> bool:
        ws = self._connections.get(device_id)
        if ws:
            await ws.send_json(data)
            return True
        return False

    def is_connected(self, device_id: str) -> bool:
        return device_id in self._connections


manager = ConnectionManager()


async def authenticate_ws(ws: WebSocket) -> Optional[Tuple[dict, str]]:
    """Extract account and device_id from a device-scoped JWT.

    Returns (account, device_id) or None. Authorization header only.
    """
    token = None
    auth_header = ws.headers.get("authorization", "").strip()
    if auth_header.startswith("Bearer "):
        token = auth_header[7:].strip() or None
    if not token:
        return None
    try:
        payload = decode_token(token)
        if payload.get("token_type") != "device":
            return None
        device_id = payload.get("device_id")
        if not device_id:
            return None
        account = await storage.get_account_by_id(payload["sub"])
        if not account:
            return None
        return (account, device_id)
    except Exception:
        return None


async def _dispatch_message(account: dict, device_id: str, data: dict) -> None:
    msg_type = data.get("type")
    if msg_type == "heartbeat":
        await storage.update_device_last_seen(device_id)
    else:
        await manager.send_json(
            device_id, {"type": "error", "message": f"unrecognized event: {msg_type}"}
        )


async def websocket_endpoint(ws: WebSocket) -> None:
    result = await authenticate_ws(ws)
    if not result:
        await ws.close(code=4001, reason="Unauthorized")
        return

    account, device_id = result

    device = await storage.get_device(device_id)
    if not device or device["account_id"] != account["id"]:
        await ws.close(code=4003, reason="Invalid device")
        return

    await manager.connect(device_id, ws)

    try:
        await manager.send_json(device_id, {"type": "hello"})
        while True:
            raw = await ws.receive_text()
            data = json.loads(raw)
            await _dispatch_message(account, device_id, data)
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(device_id)
