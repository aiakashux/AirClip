from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, EmailStr


# --- Auth ---

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    token: str
    account_id: str


# --- Device ---

class DeviceRegisterRequest(BaseModel):
    device_name: str
    platform: Literal["mac", "android", "ios"]
    public_key: str  # base64-encoded X25519 public key


class DeviceResponse(BaseModel):
    device_id: str
    device_name: str
    platform: str
    public_key: str
    trust_status: Literal["trusted"]
    created_at: datetime
    last_seen: Optional[datetime] = None
    is_online: bool = False


class DeviceRegisterResponse(DeviceResponse):
    token: str


class DeviceUpdateRequest(BaseModel):
    device_name: str


# --- Account ---

class ShortcutBindings(BaseModel):
    open_airclip: str = "cmd+shift+v"
    paste_last: str = "cmd+shift+p"


class AccountSettings(BaseModel):
    sync_enabled: bool = True
    history_days: int = 30  # 7 | 30 | 90
    encryption_enabled: bool = True
    shortcuts: ShortcutBindings = ShortcutBindings()


class AccountSettingsUpdate(BaseModel):
    sync_enabled: Optional[bool] = None
    history_days: Optional[int] = None
    encryption_enabled: Optional[bool] = None
    shortcuts: Optional[dict] = None


class AccountProfile(BaseModel):
    account_id: str
    email: str
    plan: str  # "free" for all accounts in v1
    created_at: datetime


# --- Account mutations ---

class EmailChangeRequest(BaseModel):
    new_email: EmailStr
    current_password: str


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str
