from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException

from . import storage
from .auth import create_token, get_current_user
from .schemas import DeviceRegisterRequest, DeviceRegisterResponse, DeviceResponse

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", response_model=DeviceRegisterResponse)
async def register_device(
    req: DeviceRegisterRequest,
    account: dict = Depends(get_current_user),
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
async def list_devices(account: dict = Depends(get_current_user)):
    devices = await storage.list_devices(account["id"])
    return [DeviceResponse(**d) for d in devices]


@router.post("/{device_id}/approve", response_model=DeviceResponse)
async def approve_device(
    device_id: str,
    account: dict = Depends(get_current_user),
):
    target = await storage.get_device(device_id)
    if not target or target["account_id"] != account["id"]:
        raise HTTPException(status_code=404, detail="Device not found")
    if target["trust_status"] != "pending":
        raise HTTPException(status_code=400, detail="Device is not pending approval")
    conflict = await storage.find_trusted_device_by_public_key(
        account["id"], target["public_key"],
    )
    if conflict:
        raise HTTPException(
            status_code=409,
            detail="Public key conflicts with existing trusted device",
        )
    updated = await storage.update_device_trust(device_id, "trusted")
    return DeviceResponse(**updated)
