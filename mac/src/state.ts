import * as fs from "fs";
import * as path from "path";
import { app } from "electron";

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

function getStateFilePath(): string {
  const userData = app.getPath("userData");
  return path.join(userData, "state.json");
}

export function loadState(): AppState {
  try {
    const statePath = getStateFilePath();
    if (fs.existsSync(statePath)) {
      const raw = fs.readFileSync(statePath, "utf-8");
      currentState = { ...DEFAULT_STATE, ...JSON.parse(raw) };
    }
  } catch {
    currentState = { ...DEFAULT_STATE };
  }
  return currentState;
}

export function saveState(partial: Partial<AppState>): void {
  currentState = { ...currentState, ...partial };
  const statePath = getStateFilePath();
  const dir = path.dirname(statePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(statePath, JSON.stringify(currentState, null, 2), "utf-8");
}

export function getState(): AppState {
  return currentState;
}

export function clearState(): void {
  currentState = { ...DEFAULT_STATE };
  const statePath = getStateFilePath();
  if (fs.existsSync(statePath)) {
    fs.unlinkSync(statePath);
  }
}
