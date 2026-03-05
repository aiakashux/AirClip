from __future__ import annotations

from typing import List, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import storage
from .auth import decode_token
from .schemas import ClipHistoryItem

router = APIRouter(prefix="/clips", tags=["clips"])
_security = HTTPBearer()


async def get_current_device(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
) -> Tuple[str, str]:
    """Validate a device-scoped JWT and return (account_id, device_id)."""
    payload = decode_token(credentials.credentials)
    if payload.get("token_type") != "device":
        raise HTTPException(status_code=403, detail="Device token required")
    device_id = payload.get("device_id")
    if not device_id:
        raise HTTPException(status_code=403, detail="Invalid device token")
    account = await storage.get_account_by_id(payload["sub"])
    if not account:
        raise HTTPException(status_code=401, detail="Account not found")
    device = await storage.get_device(device_id)
    if not device or device["account_id"] != account["id"]:
        raise HTTPException(status_code=403, detail="Device not found")
    return (account["id"], device_id)


@router.get("/latest_seq")
async def get_latest_seq(
    auth: Tuple[str, str] = Depends(get_current_device),
) -> dict:
    """Return the highest seq stored for the requesting device (or 0 if none)."""
    account_id, _ = auth
    seq = await storage.get_latest_seq(account_id)
    return {"latest_seq": seq}


@router.get("/", response_model=List[ClipHistoryItem])
async def get_clips(
    after_seq: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    auth: Tuple[str, str] = Depends(get_current_device),
) -> List[ClipHistoryItem]:
    """
    Return up to [limit] clips with seq > after_seq for the requesting device,
    ordered ascending by seq.  Encrypted for this device only — no cross-device leakage.
    """
    account_id, device_id = auth
    clips = await storage.get_clip_history(account_id, device_id, after_seq, limit)
    return [
        ClipHistoryItem(
            seq=c["seq"],
            message_id=c["id"],
            from_device_id=c["from_device_id"],
            ciphertext=c["ciphertext"],
            nonce=c["nonce"],
        )
        for c in clips
    ]
