from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Dict, Optional, Tuple

_log = logging.getLogger(__name__)

from fastapi import WebSocket, WebSocketDisconnect

from . import storage
from .auth import decode_token
from .schemas import (
    ClipboardMessage,
    WSDeliverClipboard,
    WSHello,
)


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

    Returns (account, device_id) or None.  The device_id is authoritative
    — no client-supplied device_id is accepted.
    """
    token = None
    auth_header = ws.headers.get("authorization", "").strip()
    if auth_header.startswith("Bearer "):
        token = auth_header[7:].strip() or None
    # HIGH 4: query-param token fallback removed — Authorization header only
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


async def deliver_pending(device_id: str) -> None:
    """Deliver any queued messages to a newly connected device."""
    messages = await storage.pop_pending_messages(device_id)
    for msg in messages:
        raw_seq = msg.get("seq")
        if isinstance(raw_seq, bool):
            # Server-side invariant violation: every stored message must carry seq >= 1.
            # Never deliver a message with seq=0 or missing seq.
            _log.error(
                "deliver_pending: msg %s has invalid seq=%r — skipping",
                msg.get("id", "?"),
                raw_seq,
            )
            continue
        try:
            seq = int(raw_seq)
        except (TypeError, ValueError):
            # Server-side invariant violation: every stored message must carry seq >= 1.
            # Never deliver a message with seq=0 or missing seq.
            _log.error(
                "deliver_pending: msg %s has invalid seq=%r — skipping",
                msg.get("id", "?"),
                raw_seq,
            )
            continue
        if seq < 1:
            # Server-side invariant violation: every stored message must carry seq >= 1.
            # Never deliver a message with seq=0 or missing seq.
            _log.error(
                "deliver_pending: msg %s has invalid seq=%r — skipping",
                msg.get("id", "?"),
                raw_seq,
            )
            continue
        outbound = WSDeliverClipboard(
            message_id=msg["id"],
            from_device_id=msg["from_device_id"],
            ciphertext=msg["ciphertext"],
            nonce=msg["nonce"],
            seq=seq,
        )
        await manager.send_json(device_id, outbound.model_dump())


async def handle_register_device(account: dict, data: dict) -> None:
    """Handle register_device WS message."""
    public_key = data.get("public_key", "")
    conflict = await storage.find_trusted_device_by_public_key(
        account["id"], public_key,
    )
    if conflict:
        return

    device = await storage.create_device(
        account_id=account["id"],
        device_name=data["device_name"],
        platform=data["platform"],
        public_key=public_key,
    )
    if device["trust_status"] == "pending":
        trusted_devices = await storage.list_devices(account["id"])
        pending_msg = WSDevicePending(
            device_id=device["device_id"],
            device_name=device["device_name"],
        )
        for d in trusted_devices:
            if d["trust_status"] == "trusted":
                await manager.send_json(d["device_id"], pending_msg.model_dump())


async def handle_approve_device(
    account: dict, caller_device_id: str, data: dict,
) -> None:
    """Handle approve_device WS message.  Only trusted devices may approve."""
    caller = await storage.get_device(caller_device_id)
    if not caller or caller["trust_status"] != "trusted":
        return

    target_id = data.get("target_device_id")
    if not target_id:
        return
    target = await storage.get_device(target_id)
    if not target or target["account_id"] != account["id"]:
        return
    if target["trust_status"] != "pending":
        return
    conflict = await storage.find_trusted_device_by_public_key(
        account["id"], target["public_key"],
    )
    if conflict:
        return
    await storage.update_device_trust(target_id, "trusted")


async def handle_send_clipboard(
    account: dict, caller_device_id: str, data: dict,
) -> None:
    """Route encrypted clipboard payloads.  Only trusted devices may send."""
    caller = await storage.get_device(caller_device_id)
    if not caller or caller["trust_status"] != "trusted":
        return

    for payload in data.get("payloads", []):
        to_device_id = payload["to_device_id"]
        target = await storage.get_device(to_device_id)
        if not target or target["account_id"] != account["id"]:
            continue
        if target["trust_status"] != "trusted":
            continue

        msg_id = str(uuid.uuid4())
        seq = await storage.next_clip_seq(account["id"])
        msg = ClipboardMessage(
            id=msg_id,
            from_device_id=caller_device_id,
            to_device_id=to_device_id,
            created_at=datetime.now(timezone.utc),
            ciphertext=payload["ciphertext"],
            nonce=payload["nonce"],
        )

        # HIGH 1: include seq in the stored dict so pending delivery also carries it
        msg_dict = {**msg.model_dump(mode="json"), "seq": seq}
        # Always store in history buffer (30-min catch-up for offline devices)
        await storage.store_clip_history(account["id"], seq, msg_dict)

        delivered = await manager.send_json(
            to_device_id,
            WSDeliverClipboard(
                message_id=msg_id,
                from_device_id=caller_device_id,
                ciphertext=payload["ciphertext"],
                nonce=payload["nonce"],
                seq=seq,
            ).model_dump(),
        )

        if not delivered:
            await storage.store_clipboard_message(msg_dict)


async def handle_ack(account_id: str, device_id: str, data: dict) -> None:
    """Delete message only if this device is the intended recipient."""
    msg_id = data.get("message_id")
    if not msg_id:
        return
    msg = await storage.get_clipboard_message(msg_id)
    if not msg:
        return  # already deleted, expired, or live-delivered
    if msg["to_device_id"] != device_id:
        return  # caller is not the intended recipient
    await storage.delete_clipboard_message(msg_id)


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
        await deliver_pending(device_id)
        latest_seq = await storage.get_latest_seq(account["id"])
        await manager.send_json(
            device_id, WSHello(latest_seq=latest_seq).model_dump()
        )

        while True:
            raw = await ws.receive_text()
            data = json.loads(raw)
            msg_type = data.get("type")

            if msg_type == "ack":
                await handle_ack(account["id"], device_id, data)
            elif msg_type == "send_clipboard":
                await handle_send_clipboard(account, device_id, data)
            elif msg_type == "approve_device":
                await handle_approve_device(account, device_id, data)
            elif msg_type == "register_device":
                await handle_register_device(account, data)

    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(device_id)
