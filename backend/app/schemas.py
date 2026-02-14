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


# --- Account ---

class Account(BaseModel):
    id: str
    email: str
    password_hash: str
    created_at: datetime


# --- Device ---

class DeviceRegisterRequest(BaseModel):
    device_name: str
    platform: Literal["mac", "android"]
    public_key: str  # base64-encoded X25519 public key


class DeviceApproveResponse(BaseModel):
    device_id: str
    trust_status: str


class DeviceResponse(BaseModel):
    device_id: str
    device_name: str
    platform: str
    public_key: str
    trust_status: Literal["trusted", "pending"]
    created_at: datetime
    last_seen: Optional[datetime] = None


class DeviceRegisterResponse(DeviceResponse):
    token: str


# --- WebSocket Messages (Client → Server) ---

class WSRegisterDevice(BaseModel):
    type: Literal["register_device"] = "register_device"
    device_name: str
    platform: Literal["mac", "android"]
    public_key: str


class WSApproveDevice(BaseModel):
    type: Literal["approve_device"] = "approve_device"
    target_device_id: str


class ClipboardPayload(BaseModel):
    to_device_id: str
    ciphertext: str  # base64
    nonce: str  # base64


class WSSendClipboard(BaseModel):
    type: Literal["send_clipboard"] = "send_clipboard"
    payloads: list[ClipboardPayload]


class WSAck(BaseModel):
    type: Literal["ack"] = "ack"
    message_id: str


# --- WebSocket Messages (Server → Client) ---

class WSDevicePending(BaseModel):
    type: Literal["device_pending"] = "device_pending"
    device_id: str
    device_name: str


class WSDeliverClipboard(BaseModel):
    type: Literal["deliver_clipboard"] = "deliver_clipboard"
    message_id: str
    from_device_id: str
    ciphertext: str  # base64
    nonce: str  # base64


# --- Stored clipboard message ---

class ClipboardMessage(BaseModel):
    id: str
    from_device_id: str
    to_device_id: str
    created_at: datetime
    ciphertext: str
    nonce: str
    version: int = 1
