from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import storage
from .auth import create_token
from .schemas import DeviceRegisterRequest, DeviceRegisterResponse, DeviceResponse

router = APIRouter(prefix="/devices", tags=["devices"])

_security = HTTPBearer()


async def _resolve_user(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
) -> dict:
    """Indirection layer so patch('backend.app.auth.get_current_user') works in tests."""
    import backend.app.auth as _auth
    return await _auth.get_current_user(credentials=credentials)


@router.post("/register", response_model=DeviceRegisterResponse)
async def register_device(
    req: DeviceRegisterRequest,
    account: dict = Depends(_resolve_user),
):
    conflict = await storage.find_trusted_device_by_public_key(
        account["id"], req.public_key,
    )
    if conflict:
        raise HTTPException(
            status_code=409,
            detail="Public key already bound to a trusted device",
        )
    device = await storage.create_device(
        account_id=account["id"],
        device_name=req.device_name,
        platform=req.platform,
        public_key=req.public_key,
    )
    device_token = create_token(account["id"], token_type="device", device_id=device["device_id"])
    return DeviceRegisterResponse(**device, token=device_token)


@router.get("/", response_model=List[DeviceResponse])
async def list_devices(account: dict = Depends(_resolve_user)):
    devices = await storage.list_devices(account["id"])
    return [DeviceResponse(**d) for d in devices]
