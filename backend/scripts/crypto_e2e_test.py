#!/usr/bin/env python3
"""
Clipr+ Crypto E2E Proof Test

Proves that real NaCl encryption works end-to-end through the backend:
plaintext is never visible to the server, only ciphertext transits Redis,
and only the intended recipient can decrypt.

Prerequisites:
    Redis running on localhost:6379
    pip install httpx pynacl

Usage:
    python backend/scripts/crypto_e2e_test.py
"""

import asyncio
import base64
import json
import os
import sys
import uuid

_BACKEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, _BACKEND_DIR)

import httpx                                            # noqa: E402
import uvicorn                                          # noqa: E402
from nacl.public import PrivateKey, PublicKey, SealedBox # noqa: E402
from websockets.asyncio.client import connect as ws_connect  # noqa: E402

PORT = 18766
BASE = f"http://127.0.0.1:{PORT}"
WS_BASE = f"ws://127.0.0.1:{PORT}"

PLAINTEXT = "hello-secure-world"

_passed = 0
_failed = 0


def step(name: str, condition: bool, detail: str = "") -> None:
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


async def run_tests() -> None:
    # ------------------------------------------------------------------
    # 1. Generate real X25519 keypairs
    # ------------------------------------------------------------------
    print("\n--- Key generation ---")

    sk_a = PrivateKey.generate()
    pk_a = sk_a.public_key
    sk_b = PrivateKey.generate()
    pk_b = sk_b.public_key

    pk_a_b64 = base64.b64encode(bytes(pk_a)).decode()
    pk_b_b64 = base64.b64encode(bytes(pk_b)).decode()

    step("Device A keypair generated",
         len(bytes(pk_a)) == 32)
    step("Device B keypair generated",
         len(bytes(pk_b)) == 32)
    step("Public keys are distinct",
         pk_a_b64 != pk_b_b64)

    # ------------------------------------------------------------------
    # 2. Register user + devices
    # ------------------------------------------------------------------
    print("\n--- Account & device registration ---")

    email = f"crypto-{uuid.uuid4().hex[:8]}@example.com"
    password = "CryptoT3st!"

    async with httpx.AsyncClient(base_url=BASE, timeout=10.0) as http:
        r = await http.post("/auth/register",
                            json={"email": email, "password": password})
        step("Register user", r.status_code == 200,
             f"status={r.status_code}")
        account_token = r.json()["token"]
        headers = {"Authorization": f"Bearer {account_token}"}

        # Device A (first → auto-trusted)
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "Crypto Mac",
            "platform": "mac",
            "public_key": pk_a_b64,
        })
        step("Register Device A", r.status_code == 200,
             f"status={r.status_code}")
        dev_a = r.json()
        dev_a_id = dev_a["device_id"]
        dev_a_token = dev_a["token"]
        step("Device A trusted", dev_a["trust_status"] == "trusted")

        # Device B (second → pending)
        r = await http.post("/devices/register", headers=headers, json={
            "device_name": "Crypto Android",
            "platform": "android",
            "public_key": pk_b_b64,
        })
        step("Register Device B", r.status_code == 200,
             f"status={r.status_code}")
        dev_b = r.json()
        dev_b_id = dev_b["device_id"]
        dev_b_token = dev_b["token"]
        step("Device B pending", dev_b["trust_status"] == "pending")

        # Approve B
        r = await http.post(f"/devices/{dev_b_id}/approve", headers=headers)
        step("Approve Device B", r.status_code == 200)

    # ------------------------------------------------------------------
    # 3. Encrypt plaintext with Device B's public key (SealedBox)
    # ------------------------------------------------------------------
    print("\n--- Encryption ---")

    sealed_box_a = SealedBox(pk_b)  # encrypt TO B using B's public key
    ciphertext_bytes = sealed_box_a.encrypt(PLAINTEXT.encode())
    ciphertext_b64 = base64.b64encode(ciphertext_bytes).decode()
    nonce_b64 = base64.b64encode(b"sealed-box-no-nonce").decode()

    step("Ciphertext produced",
         len(ciphertext_bytes) > 0)
    step("Ciphertext is not plaintext",
         PLAINTEXT not in ciphertext_b64 and PLAINTEXT.encode() not in ciphertext_bytes)
    step("Ciphertext length > plaintext length",
         len(ciphertext_bytes) > len(PLAINTEXT))

    # ------------------------------------------------------------------
    # 4. Send over WebSocket, receive, and decrypt
    # ------------------------------------------------------------------
    print("\n--- WebSocket delivery + decryption ---")

    ws_url = f"{WS_BASE}/ws"
    ws_a_hdrs = {"Authorization": f"Bearer {dev_a_token}"}
    ws_b_hdrs = {"Authorization": f"Bearer {dev_b_token}"}

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a, \
            ws_connect(ws_url, additional_headers=ws_b_hdrs) as ws_b:
        step("WS Device A connected", True)
        step("WS Device B connected", True)
        await asyncio.sleep(0.3)

        # A sends encrypted clipboard to B
        await ws_a.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": ciphertext_b64,
                "nonce": nonce_b64,
            }],
        }))
        step("Device A sent encrypted clipboard", True)

        # B receives
        raw = await asyncio.wait_for(ws_b.recv(), timeout=5.0)
        msg = json.loads(raw)
        step("Device B received deliver_clipboard",
             msg.get("type") == "deliver_clipboard",
             f"got type='{msg.get('type')}'")
        step("Ciphertext arrived intact",
             msg.get("ciphertext") == ciphertext_b64)
        step("from_device_id == Device A",
             msg.get("from_device_id") == dev_a_id)

        # B decrypts
        received_ct = base64.b64decode(msg["ciphertext"])
        unseal_box_b = SealedBox(sk_b)  # decrypt using B's private key
        decrypted = unseal_box_b.decrypt(received_ct).decode()

        step("Decryption succeeded",
             decrypted == PLAINTEXT,
             f"expected '{PLAINTEXT}', got '{decrypted}'")

        message_id = msg["message_id"]

        # ACK
        await ws_b.send(json.dumps({
            "type": "ack",
            "message_id": message_id,
        }))
        step("Device B sent ACK", True)

    # ------------------------------------------------------------------
    # 5. Verify backend/Redis never saw plaintext
    # ------------------------------------------------------------------
    print("\n--- Server-side opacity ---")

    # Send another message while B is offline so it lands in Redis,
    # then inspect the stored blob directly.
    sealed_box_a2 = SealedBox(pk_b)
    ct2_bytes = sealed_box_a2.encrypt(PLAINTEXT.encode())
    ct2_b64 = base64.b64encode(ct2_bytes).decode()

    async with ws_connect(ws_url, additional_headers=ws_a_hdrs) as ws_a2:
        await asyncio.sleep(0.2)
        await ws_a2.send(json.dumps({
            "type": "send_clipboard",
            "payloads": [{
                "to_device_id": dev_b_id,
                "ciphertext": ct2_b64,
                "nonce": nonce_b64,
            }],
        }))
        await asyncio.sleep(0.5)

    # Peek at Redis directly
    from app import storage as _st
    pending = await _st.pop_pending_messages(dev_b_id)
    step("Message found in Redis pending queue",
         len(pending) >= 1,
         f"found {len(pending)} messages")

    stored_msg = pending[0]
    stored_ct = stored_msg["ciphertext"]

    step("Stored ciphertext is base64 (not plaintext)",
         PLAINTEXT not in stored_ct)

    # Attempt to decode stored ciphertext as UTF-8 — must not yield plaintext
    try:
        raw_bytes = base64.b64decode(stored_ct)
        try:
            as_text = raw_bytes.decode("utf-8")
        except UnicodeDecodeError:
            as_text = ""
        step("Raw Redis bytes are not readable plaintext",
             PLAINTEXT not in as_text)
    except Exception:
        step("Raw Redis bytes are not readable plaintext", True)

    # Verify correct device CAN decrypt from Redis
    unseal_b2 = SealedBox(sk_b)
    redis_decrypted = unseal_b2.decrypt(raw_bytes).decode()
    step("Recipient can decrypt Redis-stored ciphertext",
         redis_decrypted == PLAINTEXT,
         f"got '{redis_decrypted}'")

    # Verify WRONG device CANNOT decrypt
    try:
        wrong_box = SealedBox(sk_a)  # A's private key, not B's
        wrong_box.decrypt(raw_bytes)
        step("Wrong device CANNOT decrypt", False,
             "decryption should have failed")
    except Exception:
        step("Wrong device CANNOT decrypt", True)

    # Clean up stored message
    await _st.delete_clipboard_message(stored_msg["id"])


async def main() -> None:
    from app.main import app

    config = uvicorn.Config(app, host="127.0.0.1", port=PORT, log_level="error")
    server = uvicorn.Server(config)
    serve_task = asyncio.create_task(server.serve())

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
    print("  Clipr+ Crypto E2E Proof Test")
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
