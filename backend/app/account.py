from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from . import storage
from .auth import get_current_user, hash_password, verify_password
from .schemas import AccountProfile, AccountSettings, AccountSettingsUpdate, EmailChangeRequest, PasswordChangeRequest

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/me", response_model=AccountProfile)
async def get_profile(account: dict = Depends(get_current_user)):
    return AccountProfile(
        account_id=account["id"],
        email=account["email"],
        plan=account.get("plan", "free"),
        created_at=account["created_at"],
    )


@router.get("/settings", response_model=AccountSettings)
async def get_settings(account: dict = Depends(get_current_user)):
    settings = await storage.get_account_settings(account["id"])
    return AccountSettings(**settings)


@router.patch("/settings", response_model=AccountSettings)
async def update_settings(
    req: AccountSettingsUpdate,
    account: dict = Depends(get_current_user),
):
    try:
        settings = await storage.update_account_settings(account["id"], req.model_dump())
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return AccountSettings(**settings)


@router.put("/email", response_model=AccountProfile)
async def change_email(
    req: EmailChangeRequest,
    account: dict = Depends(get_current_user),
):
    if not verify_password(req.current_password, account["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect password")
    existing = await storage.get_account_by_email(str(req.new_email))
    if existing and existing["id"] != account["id"]:
        raise HTTPException(status_code=409, detail="Email already in use")
    updated = await storage.update_account_email(account["id"], str(req.new_email))
    return AccountProfile(
        account_id=updated["id"],
        email=updated["email"],
        plan=updated.get("plan", "free"),
        created_at=updated["created_at"],
    )


@router.put("/password", status_code=204)
async def change_password(
    req: PasswordChangeRequest,
    account: dict = Depends(get_current_user),
):
    if not verify_password(req.current_password, account["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect password")
    if len(req.new_password) < 8:
        raise HTTPException(status_code=422, detail="Password must be at least 8 characters")
    await storage.update_account_password(account["id"], hash_password(req.new_password))
