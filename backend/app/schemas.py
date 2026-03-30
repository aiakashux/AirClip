from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, EmailStr, field_serializer, field_validator


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


# --- Deprecated / compatibility stubs (used by ws.py until Task 5 removes them) ---

class WSDevicePending(BaseModel):
    type: Literal["device_pending"] = "device_pending"
    device_id: str
    device_name: str


# --- WebSocket Messages (Client → Server) ---

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

class WSHello(BaseModel):
    type: Literal["hello"] = "hello"
    latest_seq: int  # serialised as string — see field_serializer below

    @field_serializer("latest_seq")
    def serialize_latest_seq(self, v: int) -> str:
        return str(v)


class WSDeliverClipboard(BaseModel):
    type: Literal["deliver_clipboard"] = "deliver_clipboard"
    message_id: str
    from_device_id: str
    ciphertext: str  # base64
    nonce: str  # base64
    seq: int  # monotonic per-account seq; required, must be >= 1; serialised as string

    @field_validator("seq")
    @classmethod
    def seq_must_be_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError(f"seq must be >= 1, got {v}")
        return v

    @field_serializer("seq")
    def serialize_seq(self, v: int) -> str:
        return str(v)


# --- Stored clipboard message ---

class ClipboardMessage(BaseModel):
    id: str
    from_device_id: str
    to_device_id: str
    created_at: datetime
    ciphertext: str
    nonce: str
    version: int = 1


# --- Clip history REST response ---

class ClipHistoryItem(BaseModel):
    seq: int  # serialised as string — see field_serializer below
    message_id: str
    from_device_id: str
    ciphertext: str  # base64 — encrypted for the requesting device
    nonce: str       # base64

    @field_serializer("seq")
    def serialize_seq(self, v: int) -> str:
        return str(v)
