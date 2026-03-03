from __future__ import annotations

import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import storage
from .auth import router as auth_router
from .clips import router as clips_router
from .devices import router as devices_router
from .ws import websocket_endpoint

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
    await storage.init_redis(redis_url)
    yield
    await storage.close_redis()


app = FastAPI(title="Clipr+", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(devices_router)
app.include_router(clips_router)
app.add_api_websocket_route("/ws", websocket_endpoint)
