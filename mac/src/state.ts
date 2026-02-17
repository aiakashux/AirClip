import * as fs from "fs";
import * as path from "path";
import { STATE_FILE_PATH } from "./config";

export interface AppState {
  account_token: string | null;
  account_id: string | null;
  device_id: string | null;
  device_token: string | null;
  public_key_b64: string | null;
  private_key_b64: string | null;
}

const DEFAULT_STATE: AppState = {
  account_token: null,
  account_id: null,
  device_id: null,
  device_token: null,
  public_key_b64: null,
  private_key_b64: null,
};

let currentState: AppState = { ...DEFAULT_STATE };

export function loadState(): AppState {
  try {
    if (fs.existsSync(STATE_FILE_PATH)) {
      const raw = fs.readFileSync(STATE_FILE_PATH, "utf-8");
      currentState = { ...DEFAULT_STATE, ...JSON.parse(raw) };
    }
  } catch {
    currentState = { ...DEFAULT_STATE };
  }
  return currentState;
}

export function saveState(partial: Partial<AppState>): void {
  currentState = { ...currentState, ...partial };
  const dir = path.dirname(STATE_FILE_PATH);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(STATE_FILE_PATH, JSON.stringify(currentState, null, 2), "utf-8");
}

export function getState(): AppState {
  return currentState;
}

export function clearState(): void {
  currentState = { ...DEFAULT_STATE };
  if (fs.existsSync(STATE_FILE_PATH)) {
    fs.unlinkSync(STATE_FILE_PATH);
  }
}
