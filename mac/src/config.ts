import * as path from "path";

export const BACKEND_HTTP_BASE = "http://localhost:8000";
export const BACKEND_WS_BASE = "ws://localhost:8000/ws";
export const STATE_FILE_PATH = path.join(__dirname, "..", ".local", "state.json");
