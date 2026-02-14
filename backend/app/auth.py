from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import storage
from .schemas import LoginRequest, RegisterRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode(), password_hash.encode())


def create_token(
    account_id: str,
    token_type: str = "account",
    device_id: str = None,
) -> str:
    payload = {
        "sub": account_id,
        "token_type": token_type,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRY_HOURS),
        "iat": datetime.now(timezone.utc),
    }
    if device_id is not None:
        payload["device_id"] = device_id
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    payload = decode_token(credentials.credentials)
    if payload.get("token_type") != "account":
        raise HTTPException(status_code=403, detail="Account token required")
    account = await storage.get_account_by_id(payload["sub"])
    if not account:
        raise HTTPException(status_code=401, detail="Account not found")
    return account


@router.post("/register", response_model=TokenResponse)
async def register(req: RegisterRequest):
    account = await storage.create_account(req.email, hash_password(req.password))
    if account is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )
    token = create_token(account["id"])
    return TokenResponse(token=token, account_id=account["id"])


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest):
    account = await storage.get_account_by_email(req.email)
    if not account or not verify_password(req.password, account["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_token(account["id"])
    return TokenResponse(token=token, account_id=account["id"])
