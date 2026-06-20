from __future__ import annotations

import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import storage
from .account import router as account_router
from .auth import router as auth_router
from .devices import router as devices_router
from .ws import websocket_endpoint

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    db_path = os.getenv("DB_PATH", "airclip.db")
    await storage.init_db(db_path)
    yield
    await storage.close_db()


app = FastAPI(title="AirClip", version="0.2.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(account_router)
app.include_router(devices_router)
app.add_api_websocket_route("/ws", websocket_endpoint)
