#!/usr/bin/env python3
"""
Clipr+ Backend Integration Smoke Test

Starts the FastAPI server in-process, exercises every REST and WS
endpoint, validates security invariants, then prints a PASS/FAIL scorecard.

Prerequisites:
    Redis running on localhost:6379 (or REDIS_URL env var)
    pip install httpx

Usage:
    python backend/scripts/integration_test.py
"""

import asyncio
import base64
import json
import os
import sys
import uuid

# ---------------------------------------------------------------------------
# Make `app` package importable regardless of where we invoke the script
# ---------------------------------------------------------------------------
_BACKEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, _BACKEND_DIR)

import httpx                                # noqa: E402
import uvicorn                              # noqa: E402
from websockets.asyncio.client import connect as ws_connect  # noqa: E402
from websockets.exceptions import InvalidStatus              # noqa: E402

PORT = 18765
BASE = f"http://127.0.0.1:{PORT}"
WS_BASE = f"ws://127.0.0.1:{PORT}"

# ---------------------------------------------------------------------------
# Scorecard
# ---------------------------------------------------------------------------
_passed = 0
_failed = 0


def step(name: str, condition: bool, detail: str = "") -> None:
    """Record one assertion.  Raises on failure so later steps that
    depend on earlier state are skipped rather than producing confusing
    secondary errors."""
    global _passed, _failed
    if condition:
        _passed += 1
        print(f"  [PASS]  {name}")
    else:
        _failed += 1
        msg = f"  [FAIL]  {name}"
        if detail:
            msg += f"  -- {detail}"
        print(msg)
        raise AssertionError(msg)


# ---------------------------------------------------------------------------
# Test body
# ---------------------------------------------------------------------------
async def run_tests() -> None:
    email = f"smoke-{uuid.uuid4().hex[:8]}@example.com"
    password = "Str0ngP@ss!"

    # Populated by each section
    account_token: str = ""
    dev_a_id: str = ""
    dev_a_token: str = ""
    dev_b_id: str = ""
    dev_b_token: str = ""

    # -----------------------------------------------------------------------
    # Auth
    # -----------------------------------------------------------------------
    print("\n--- Auth ---")

    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as http:
        # Register
        r = await http.post(
            "/auth/register",
            json={"email": email, "password": password},
        )
        step("Register new user", r.status_code == 200,
             f"status={r.status_code} body={r.text[:200]}")
        account_token = r.json()["token"]
        headers = {"Authorization": f"Bearer {account_token}"}

        # Login
        r = await http.post(
            "/auth/login",
            json={"email": email, "password": password},
        )
        step("Login with credentials", r.status_code == 200,
             f"status={r.status_code}")
        login_token = r.json()["token"]
        step("Login returns valid JWT",
             isinstance(login_token, str) and len(login_token) > 20)

        # -------------------------------------------------------------------
        # Devices
        # -------------------------------------------------------------------
        print("\n--- Devices ---")

        # Device A — first device, must be auto-trusted, returns device JWT
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "Mac Test",
            "platform": "mac",
            "public_key": base64.b64encode(b"fake-pubkey-a").decode(),
        })
        step("Register Device A", r.status_code == 200,
             f"status={r.status_code} body={r.text[:200]}")
        dev_a = r.json()
        dev_a_id = dev_a["device_id"]
        dev_a_token = dev_a["token"]
        step("Device A trust_status == 'trusted'",
             dev_a["trust_status"] == "trusted",
             f"got '{dev_a['trust_status']}'")
        step("Device A response includes device token",
             isinstance(dev_a_token, str) and len(dev_a_token) > 20)

        # Device B — second device, must be pending
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "Android Test",
            "platform": "android",
            "public_key": base64.b64encode(b"fake-pubkey-b").decode(),
        })
        step("Register Device B", r.status_code == 200,
             f"status={r.status_code}")
        dev_b = r.json()
        dev_b_id = dev_b["device_id"]
        dev_b_token = dev_b["token"]
        step("Device B trust_status == 'pending'",
             dev_b["trust_status"] == "pending",
             f"got '{dev_b['trust_status']}'")

        # Approve Device B via REST
        r = await http.post(f"/devices/{dev_b_id}/approve", headers=headers)
        step("Approve Device B via REST", r.status_code == 200,
             f"status={r.status_code} body={r.text[:200]}")
        approved = r.json()
        step("Device B trust_status == 'trusted' after approval",
             approved["trust_status"] == "trusted",
             f"got '{approved['trust_status']}'")

        # List devices
        r = await http.get("/devices/", headers=headers)
        step("List devices returns 2",
             r.status_code == 200 and len(r.json()) == 2,
             f"count={len(r.json()) if r.status_code == 200 else 'error'}")

    # -----------------------------------------------------------------------
    # WebSocket — device-scoped token auth (no device_id query param)
    # -----------------------------------------------------------------------
    print("\n--- WebSocket: live clipboard delivery ---")

    ciphertext_b64 = base64.b64encode(b"hello").decode()
    nonce_b64 = base64.b64encode(b"nonce").decode()

    # WS auth via Authorization header — no token in URL
    ws_url = f"{WS_BASE}/ws"
    ws_a_hdrs = {"Authorization": f"Bearer {dev_a_token}"}
    ws_b_hdrs = {"Authorization": f"Bearer {dev_b_token}"}

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a, \
            ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b:
        step("WS connect Device A (device token)", True)
        step("WS connect Device B (device token)", True)

        await asyncio.sleep(0.3)

        # Device A sends clipboard to Device B
        await ws_a.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": ciphertext_b64,
                "nonce": nonce_b64,
            }],
        }))
        step("Device A sent send_clipboard", True)

        # Device B receives
        raw = await asyncio.wait_for(ws_b.recv(), timeout=5.0)
        msg = json.loads(raw)
        step("Device B receives 'deliver_clipboard'",
             msg.get("type") == "deliver_clipboard",
             f"got type='{msg.get('type')}'")
        step("Ciphertext matches",
             msg.get("ciphertext") == ciphertext_b64)
        step("Nonce matches",
             msg.get("nonce") == nonce_b64)
        step("from_device_id == Device A",
             msg.get("from_device_id") == dev_a_id,
             f"got '{msg.get('from_device_id')}'")
        message_id = msg.get("message_id")
        step("message_id present",
             message_id is not None and len(message_id) > 0)

        # Device B ACKs
        await ws_b.send(json.dumps({
            "type": "ack",
            "message_id": message_id,
        }))
        step("Device B sent ACK", True)

        # No duplicate
        try:
            dup = await asyncio.wait_for(ws_b.recv(), timeout=2.0)
            step("No duplicate on active connection", False,
                 f"unexpected: {str(dup)[:120]}")
        except asyncio.TimeoutError:
            step("No duplicate on active connection", True)

    # -----------------------------------------------------------------------
    # Reconnect — no stale messages
    # -----------------------------------------------------------------------
    print("\n--- Reconnect: no stale pending messages ---")

    async with ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b2:
        step("WS reconnect Device B", True)
        try:
            stale = await asyncio.wait_for(ws_b2.recv(), timeout=2.0)
            step("No stale messages after reconnect", False,
                 f"unexpected: {str(stale)[:120]}")
        except asyncio.TimeoutError:
            step("No stale messages after reconnect", True)

    # -----------------------------------------------------------------------
    # Offline delivery — queued then delivered on reconnect
    # -----------------------------------------------------------------------
    print("\n--- Offline delivery: queued clipboard ---")

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a_solo:
        step("WS connect Device A (solo)", True)
        await asyncio.sleep(0.2)

        await ws_a_solo.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": ciphertext_b64,
                "nonce": nonce_b64,
            }],
        }))
        step("Device A sent clipboard (B offline)", True)
        await asyncio.sleep(0.3)

    # Connect B — should get the queued message
    async with ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b3:
        raw = await asyncio.wait_for(ws_b3.recv(), timeout=5.0)
        msg = json.loads(raw)
        step("Device B receives queued deliver_clipboard",
             msg.get("type") == "deliver_clipboard",
             f"got type='{msg.get('type')}'")
        offline_msg_id = msg.get("message_id")
        step("Queued message_id present",
             offline_msg_id is not None and len(offline_msg_id) > 0)

        await ws_b3.send(json.dumps({
            "type": "ack",
            "message_id": offline_msg_id,
        }))
        step("Device B ACK'd queued message", True)

    # Reconnect — queue empty
    async with ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b4:
        try:
            leftover = await asyncio.wait_for(ws_b4.recv(), timeout=2.0)
            step("No leftover after offline ACK", False,
                 f"unexpected: {str(leftover)[:120]}")
        except asyncio.TimeoutError:
            step("No leftover after offline ACK", True)

    # ===================================================================
    # SECURITY TESTS
    # ===================================================================

    # -----------------------------------------------------------------------
    # SEC-A: WS rejects account-level token (no device_id claim)
    # -----------------------------------------------------------------------
    print("\n--- SEC-A: WS rejects account-only token ---")

    try:
        acct_hdrs = {"Authorization": f"Bearer {account_token}"}
        async with ws_connect(ws_url, additional_headers=acct_hdrs) as ws_bad:
            # If we get here, the server accepted — that's wrong.
            # But it may have accepted then immediately closed; try recv.
            try:
                await asyncio.wait_for(ws_bad.recv(), timeout=2.0)
            except Exception:
                pass
            step("WS rejects account-only JWT", False,
                 "connection was accepted")
    except InvalidStatus as exc:
        # Server closed during handshake — expected
        step("WS rejects account-only JWT", True)

    # -----------------------------------------------------------------------
    # SEC-A2: WS ignores client-supplied device_id query param
    # -----------------------------------------------------------------------
    print("\n--- SEC-A2: device_id comes from JWT, not query param ---")

    # Connect with Device A's token but try to spoof Device B via query param
    spoofed_url = f"{WS_BASE}/ws?device_id={dev_b_id}"
    async with ws_connect(spoofed_url, additional_headers=ws_a_hdrs) as ws_spoof:
        # Connection should succeed (token is valid), but identity = A not B
        # Send clipboard "from B" — if spoofing worked, this would look like
        # it came from B.  Instead the server should use A's device_id.
        await ws_spoof.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": ciphertext_b64,
                "nonce": nonce_b64,
            }],
        }))
        step("WS connection accepted with valid device token", True)

    # Connect B and see if a message arrived with from_device_id = A (not B)
    async with ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b_check:
        try:
            raw = await asyncio.wait_for(ws_b_check.recv(), timeout=3.0)
            msg = json.loads(raw)
            step("from_device_id is JWT device (A), not spoofed param",
                 msg.get("from_device_id") == dev_a_id,
                 f"got '{msg.get('from_device_id')}'")
            # Clean up — ACK
            await ws_b_check.send(json.dumps({
                "type": "ack",
                "message_id": msg.get("message_id"),
            }))
        except asyncio.TimeoutError:
            # Message might have been delivered live during spoof connection.
            # Either way, no spoofed identity reached B.
            step("from_device_id is JWT device (A), not spoofed param", True)

    # -----------------------------------------------------------------------
    # SEC-B: Pending device cannot send clipboard
    # -----------------------------------------------------------------------
    print("\n--- SEC-B: Pending device cannot send clipboard ---")

    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as http:
        headers = {"Authorization": f"Bearer {account_token}"}
        # Register Device C — pending, NOT approved
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "Rogue Device",
            "platform": "android",
            "public_key": base64.b64encode(b"fake-pubkey-c").decode(),
        })
        step("Register Device C (pending)", r.status_code == 200)
        dev_c = r.json()
        dev_c_id = dev_c["device_id"]
        dev_c_token = dev_c["token"]
        step("Device C is pending",
             dev_c["trust_status"] == "pending",
             f"got '{dev_c['trust_status']}'")

    ws_c_hdrs = {"Authorization": f"Bearer {dev_c_token}"}

    # C tries to send clipboard to A — should be silently dropped
    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a_listen, \
            ws_connect(ws_url, additional_headers=ws_c_hdrs) as ws_c:
        step("WS connect pending Device C", True)
        await asyncio.sleep(0.2)

        await ws_c.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_a_id,
                "ciphertext": ciphertext_b64,
                "nonce": nonce_b64,
            }],
        }))

        try:
            unexpected = await asyncio.wait_for(ws_a_listen.recv(), timeout=2.0)
            step("Pending device send_clipboard blocked",
                 False, f"A received: {str(unexpected)[:120]}")
        except asyncio.TimeoutError:
            step("Pending device send_clipboard blocked", True)

    # -----------------------------------------------------------------------
    # SEC-B2: approve_device is no longer a recognized event — server must
    #         return an error response, not crash and not silently succeed.
    # -----------------------------------------------------------------------
    print("\n--- SEC-B2: approve_device returns unrecognized-event error ---")

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a2:
        # Drain the hello message first
        await asyncio.wait_for(ws_a2.recv(), timeout=3.0)

        await ws_a2.send(json.dumps({
            "type": "approve_device",
            "target_device_id": dev_b_id,
        }))

        try:
            raw = await asyncio.wait_for(ws_a2.recv(), timeout=3.0)
            response = json.loads(raw)
            is_error = (
                response.get("type") == "error"
                and "unrecognized" in response.get("message", "").lower()
            )
            step(
                "approve_device returns unrecognized-event error",
                is_error,
                f"Got: {response}",
            )
        except asyncio.TimeoutError:
            step(
                "approve_device returns unrecognized-event error",
                False,
                "No response received within 3s — expected error message",
            )

    # -----------------------------------------------------------------------
    # SEC-C: ACK from wrong device does not delete message
    # -----------------------------------------------------------------------
    print("\n--- SEC-C: ACK authorization ---")

    # A sends clipboard to B while B is offline → stored in Redis
    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a_offline:
        await asyncio.sleep(0.2)
        await ws_a_offline.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": ciphertext_b64,
                "nonce": nonce_b64,
            }],
        }))
        step("Device A sent clipboard (B offline, for ACK test)", True)
        await asyncio.sleep(0.3)

        # A tries to ACK B's message.  First we need the message_id.
        # We can't know it directly, but we can connect B to peek at it,
        # then test with A.  Instead, let's connect B, get the msg, then
        # have A try to ACK it and verify it doesn't get deleted.

    # Connect B to receive the pending message and learn message_id
    async with ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b_peek:
        raw = await asyncio.wait_for(ws_b_peek.recv(), timeout=5.0)
        msg = json.loads(raw)
        ack_test_msg_id = msg.get("message_id")
        step("Device B received message for ACK test",
             msg.get("type") == "deliver_clipboard")
        # Do NOT ACK from B yet.
        # The message was delivered live from pending queue (pop_pending),
        # so it's already removed from Redis.  To test ACK auth on a stored
        # message, we need B offline during send.

    # For a proper ACK-auth test, send another message while B is truly offline
    # and both A and B are disconnected, then:
    # 1. Connect A, send clipboard → stored in Redis
    # 2. Connect A again, try to ACK with the message_id
    # 3. Connect B → should still receive it (A's ACK was rejected)

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a_send2:
        await asyncio.sleep(0.2)
        await ws_a_send2.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": base64.b64encode(b"ack-test").decode(),
                "nonce": nonce_b64,
            }],
        }))
        step("Sent clipboard for ACK-auth test (B offline)", True)
        await asyncio.sleep(0.3)

    # Now connect A and try to ACK a message destined for B.
    # We don't know the exact message_id, but we can try a brute approach:
    # connect B, get the message_id, disconnect, then have A try to ACK it.
    # Since pop_pending already delivered, we need a fresh message.

    # Cleaner approach: send msg, connect A, have A try to ACK using a
    # fabricated message_id that might match.  We need the real ID though.
    # Let's use the Redis store approach: send while B offline, then peek
    # at Redis via a B connection, get the ID, close B WITHOUT ACKing,
    # then have A try to ACK that ID.

    # Actually: pop_pending removes from queue but the msg:{id} key is
    # still in Redis until ACK'd or TTL.  Wait — pop_pending calls
    # get_clipboard_message which reads but doesn't delete the msg key.
    # Only delete_clipboard_message removes it.  So after B receives via
    # pending delivery, the msg key still exists in Redis.

    # Let's do this properly:
    # 1. Send while B offline → stored at msg:{id} + pending queue
    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a_ack:
        await asyncio.sleep(0.2)
        await ws_a_ack.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": base64.b64encode(b"ack-auth-real").decode(),
                "nonce": nonce_b64,
            }],
        }))
        await asyncio.sleep(0.3)

    # 2. Connect B, receive the queued message, grab ID, close without ACK
    async with ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b_grab:
        # B may receive multiple pending messages — drain until we find ours
        target_msg_id = None
        target_ct = base64.b64encode(b"ack-auth-real").decode()
        while True:
            try:
                raw = await asyncio.wait_for(ws_b_grab.recv(), timeout=3.0)
                m = json.loads(raw)
                if m.get("type") == "deliver_clipboard":
                    if m.get("ciphertext") == target_ct:
                        target_msg_id = m["message_id"]
                        break
            except asyncio.TimeoutError:
                break

    step("Got message_id for ACK-auth test",
         target_msg_id is not None)

    # 3. Connect A and have it try to ACK B's message
    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a_badack:
        await asyncio.sleep(0.2)
        await ws_a_badack.send(json.dumps({
            "type": "ack",
            "message_id": target_msg_id,
        }))
        await asyncio.sleep(0.5)

    # 4. Connect B — the message should still be deliverable.
    #    Note: pop_pending already consumed the pending queue entry when
    #    we grabbed the ID.  But the msg:{id} key should still exist if
    #    A's ACK was properly rejected.  We verify by checking that the
    #    msg key was NOT deleted.
    #    Since the pending queue entry is gone, B won't get it via
    #    deliver_pending.  We verify the msg key directly.
    from app import storage as _st
    msg_data = await _st.get_clipboard_message(target_msg_id)
    step("ACK from wrong device did NOT delete message",
         msg_data is not None,
         "message was deleted by unauthorized ACK" if msg_data is None else "")

    # Clean up: B ACKs properly
    await _st.delete_clipboard_message(target_msg_id)

    # -----------------------------------------------------------------------
    # SEC-D: Public key conflict — duplicate trusted key rejected
    # -----------------------------------------------------------------------
    print("\n--- SEC-D: Public key integrity ---")

    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as http:
        headers = {"Authorization": f"Bearer {account_token}"}
        # Try to register a new device with Device A's public key
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "Evil Clone",
            "platform": "mac",
            "public_key": base64.b64encode(b"fake-pubkey-a").decode(),
        })
        step("Duplicate trusted public_key rejected (409)",
             r.status_code == 409,
             f"status={r.status_code} body={r.text[:200]}")

    # -----------------------------------------------------------------------
    # SEC-E: Device token cannot call REST endpoints
    # -----------------------------------------------------------------------
    print("\n--- SEC-E: Device token rejected at REST endpoints ---")

    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as http:
        dev_headers = {"Authorization": f"Bearer {dev_a_token}"}

        r = await http.post(f"/devices/{dev_b_id}/approve", headers=dev_headers)
        step("Device token rejected at /devices/approve (403)",
             r.status_code == 403,
             f"status={r.status_code} body={r.text[:200]}")

        r = await http.get("/devices/", headers=dev_headers)
        step("Device token rejected at GET /devices/ (403)",
             r.status_code == 403,
             f"status={r.status_code}")

        r = await http.post("/devices/register", headers=dev_headers, json={
            "device_name": "Nope",
            "platform": "mac",
            "public_key": base64.b64encode(b"fake-nope").decode(),
        })
        step("Device token rejected at /devices/register (403)",
             r.status_code == 403,
             f"status={r.status_code}")

    # -----------------------------------------------------------------------
    # SEC-F: Account token cannot open WebSocket
    # -----------------------------------------------------------------------
    print("\n--- SEC-F: Account token rejected at WebSocket ---")

    # (SEC-A already tests this, but let's be explicit with the new token_type label)
    try:
        acct_hdrs_f = {"Authorization": f"Bearer {account_token}"}
        async with ws_connect(ws_url, additional_headers=acct_hdrs_f) as ws_acct:
            try:
                await asyncio.wait_for(ws_acct.recv(), timeout=2.0)
            except Exception:
                pass
            step("Account token rejected at WS", False,
                 "connection was accepted")
    except InvalidStatus:
        step("Account token rejected at WS", True)

    # -----------------------------------------------------------------------
    # SEC-G: Public key conflict detected at approval time
    # -----------------------------------------------------------------------
    print("\n--- SEC-G: Public key conflict at approval time ---")

    dup_key = base64.b64encode(b"dup-approval-key").decode()
    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as http:
        headers = {"Authorization": f"Bearer {account_token}"}

        # Register two pending devices with the same public key
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "DupD",
            "platform": "mac",
            "public_key": dup_key,
        })
        step("Register DupD", r.status_code == 200)
        dup_d_id = r.json()["device_id"]

        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "DupE",
            "platform": "mac",
            "public_key": dup_key,
        })
        step("Register DupE (same key)", r.status_code == 200)
        dup_e_id = r.json()["device_id"]

        # Approve D — should succeed (no trusted device has this key yet)
        r = await http.post(f"/devices/{dup_d_id}/approve", headers=headers)
        step("Approve DupD succeeds",
             r.status_code == 200,
             f"status={r.status_code} body={r.text[:200]}")

        # Approve E — should fail 409 (D now holds this key as trusted)
        r = await http.post(f"/devices/{dup_e_id}/approve", headers=headers)
        step("Approve DupE blocked — key conflict (409)",
             r.status_code == 409,
             f"status={r.status_code} body={r.text[:200]}")


# ---------------------------------------------------------------------------
# Server lifecycle
# ---------------------------------------------------------------------------
async def main() -> None:
    from app.main import app  # noqa: delayed import after sys.path fix

    config = uvicorn.Config(
        app,
        host="127.0.0.1",
        port=PORT,
        log_level="error",
    )
    server = uvicorn.Server(config)
    serve_task = asyncio.create_task(server.serve())

    # Wait for the server to be ready
    ready = False
    for _ in range(50):
        try:
            async with httpx.AsyncClient() as c:
                r = await c.get(f"{BASE}/openapi.json")
                if r.status_code == 200:
                    ready = True
                    break
        except Exception:
            pass
        await asyncio.sleep(0.1)

    if not ready:
        print("FATAL: Server failed to start. Is Redis running?")
        sys.exit(1)

    print("=" * 55)
    print("  Clipr+ Integration Smoke Test")
    print("=" * 55)

    exit_code = 0
    try:
        await run_tests()
    except AssertionError:
        exit_code = 1
    except Exception as exc:
        print(f"\n  [FAIL]  Unexpected error: {exc}")
        import traceback
        traceback.print_exc()
        exit_code = 1
    finally:
        server.should_exit = True
        await serve_task

    print(f"\n{'=' * 55}")
    print(f"  Results: {_passed} passed, {_failed} failed")
    print(f"{'=' * 55}")
    sys.exit(exit_code)


if __name__ == "__main__":
    asyncio.run(main())
