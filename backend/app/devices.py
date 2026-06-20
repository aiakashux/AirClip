from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException

from . import storage
from .auth import create_token, get_current_user
from .schemas import DeviceRegisterRequest, DeviceRegisterResponse, DeviceResponse, DeviceUpdateRequest

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", response_model=DeviceRegisterResponse)
async def register_device(
    req: DeviceRegisterRequest,
    account: dict = Depends(get_current_user),
):
    conflict = await storage.find_trusted_device_by_public_key(account["id"], req.public_key)
    if conflict:
        raise HTTPException(status_code=409, detail="Public key already bound to a trusted device")
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


@router.patch("/{device_id}", response_model=DeviceResponse)
async def rename_device(
    device_id: str,
    req: DeviceUpdateRequest,
    account: dict = Depends(get_current_user),
):
    device = await storage.get_device(device_id)
    if not device or device["account_id"] != account["id"]:
        raise HTTPException(status_code=404, detail="Device not found")
    updated = await storage.update_device_name(device_id, req.device_name)
    return DeviceResponse(**updated)


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: str,
    account: dict = Depends(get_current_user),
):
    removed = await storage.delete_device(account["id"], device_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Device not found")
