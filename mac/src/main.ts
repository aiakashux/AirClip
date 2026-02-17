import { app, Tray, Menu, BrowserWindow, ipcMain, nativeImage, clipboard } from "electron";
import * as crypto from "crypto";
import * as path from "path";
import { loadState, saveState, getState, clearState } from "./state";
import { initCrypto, generateKeypair, encryptForDevice, decryptFromDevice, toB64, fromB64, pubKeyFromB64 } from "./crypto";
import * as api from "./api";
import { WsClient, DeliverClipboardEvent } from "./websocket";

console.log("Clipr starting...");

let tray: Tray | null = null;
let loginWindow: BrowserWindow | null = null;
let logsWindow: BrowserWindow | null = null;
let wsClient: WsClient | null = null;

// Loop-prevention state (in-memory only)
let lastLocalHash: string | null = null;
let lastRemoteHash: string | null = null;
let clipboardPollTimer: ReturnType<typeof setInterval> | null = null;

function sha256hex(text: string): string {
  return crypto.createHash("sha256").update(text).digest("hex");
}

// ---------------------------------------------------------------------------
// Clipboard items list (in-memory, max 10)
// ---------------------------------------------------------------------------
interface ClipboardItem {
  id: string;
  source_device_label: string;
  source_device_id: string;
  text: string;
  hash: string;
  ts: number;
  direction: "local" | "remote";
}

const MAX_CLIPBOARD_ITEMS = 10;
let clipboardItems: ClipboardItem[] = [];

function upsertClipboardItem(item: Omit<ClipboardItem, "id">): void {
  const existing = clipboardItems.findIndex((i) => i.hash === item.hash);
  if (existing !== -1) {
    clipboardItems.splice(existing, 1);
  }
  clipboardItems.unshift({
    id: crypto.randomUUID(),
    ...item,
  });
  if (clipboardItems.length > MAX_CLIPBOARD_ITEMS) {
    clipboardItems = clipboardItems.slice(0, MAX_CLIPBOARD_ITEMS);
  }
  pushClipboardItemsToRenderer();
}

function pushClipboardItemsToRenderer(): void {
  if (logsWindow && !logsWindow.isDestroyed()) {
    logsWindow.webContents.send("clipboard_items_updated", clipboardItems);
  }
}

function log(msg: string): void {
  console.log(`[Clipr+] ${msg}`);
  if (logsWindow && !logsWindow.isDestroyed()) {
    logsWindow.webContents.send("log", msg);
  }
}

function createLoginWindow(): void {
  if (loginWindow && !loginWindow.isDestroyed()) {
    loginWindow.focus();
    return;
  }
  loginWindow = new BrowserWindow({
    width: 340,
    height: 280,
    resizable: false,
    title: "Clipr+",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  loginWindow.loadFile(path.join(__dirname, "renderer", "login.html"));
  loginWindow.on("closed", () => { loginWindow = null; });
}

function createLogsWindow(): void {
  if (logsWindow && !logsWindow.isDestroyed()) {
    logsWindow.show();
    logsWindow.focus();
    return;
  }
  logsWindow = new BrowserWindow({
    width: 480,
    height: 360,
    title: "Clipr+ Logs",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  logsWindow.loadFile(path.join(__dirname, "renderer", "logs.html"));
  logsWindow.on("closed", () => { logsWindow = null; });
}

function resetAllState(): void {
  setAccountToken(null);
  clearState();
}

function setAccountToken(nextToken: string | null): void {
  const prev = getState().account_token;
  if (prev && prev !== nextToken) {
    api.invalidateDevicesCache(prev);
    log("Devices cache invalidated (account change)");
  }
  if (!nextToken) {
    api.invalidateDevicesCache();
  }
  saveState({ account_token: nextToken });
}

async function doAuth(action: "login" | "register", email: string, password: string): Promise<{ ok: boolean; error?: string }> {
  try {
    const authFn = action === "login" ? api.login : api.register;
    const { token, account_id } = await authFn(email, password);
    setAccountToken(token);
    saveState({ account_id });
    log(`Auth success (${action}). account_id=${account_id}`);

    await ensureDeviceRegistered();
    connectWs();

    return { ok: true };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    log(`Auth error: ${msg}`);
    return { ok: false, error: msg };
  }
}

async function ensureDeviceRegistered(): Promise<void> {
  const state = getState();
  if (state.device_id && state.device_token) {
    log(`Device already registered: ${state.device_id}`);
    return;
  }

  await initCrypto();
  const kp = generateKeypair();
  const pub_b64 = toB64(kp.publicKey);
  const priv_b64 = toB64(kp.privateKey);

  const hostname = require("os").hostname() || "Mac";
  const res = await api.registerDevice(state.account_token!, hostname, "mac", pub_b64);

  saveState({
    device_id: res.device_id,
    device_token: res.token,
    public_key_b64: pub_b64,
    private_key_b64: priv_b64,
  });

  log(`Device registered: ${res.device_id} (${res.trust_status})`);
}

function connectWs(): void {
  const state = getState();
  if (!state.device_token) {
    log("No device token — cannot connect WS");
    return;
  }
  if (wsClient) {
    wsClient.disconnect();
  }
  stopClipboardPolling();
  wsClient = new WsClient(state.device_token);

  wsClient.on("log", (msg: string) => log(msg));

  wsClient.on("open", () => {
    const st = getState();
    if (st.account_token) {
      api.getDevicesCached(st.account_token, 10_000, {
        force: true,
        onFetch: (n) => log(`Fetched devices from server count=${n}`),
      });
    }
    startClipboardPolling();
  });
  wsClient.on("close", () => stopClipboardPolling());

  wsClient.on("deliver_clipboard", async (evt: DeliverClipboardEvent) => {
    const st = getState();
    if (evt.from_device_id === st.device_id) {
      log("Ignoring message from self");
      return;
    }
    if (!st.public_key_b64 || !st.private_key_b64) {
      log("Cannot decrypt: no keypair");
      return;
    }
    try {
      await initCrypto();
      const plaintext = decryptFromDevice(
        evt.ciphertext,
        fromB64(st.public_key_b64),
        fromB64(st.private_key_b64)
      );
      const hash = sha256hex(plaintext);
      const hashPrefix = hash.slice(0, 16);

      upsertClipboardItem({
        source_device_label: `Remote (${evt.from_device_id.slice(0, 8)})`,
        source_device_id: evt.from_device_id,
        text: plaintext,
        hash,
        ts: Date.now(),
        direction: "remote",
      });

      log(`Received msg=${evt.message_id} hash=${hashPrefix} len=${plaintext.length}`);
      wsClient!.sendAck(evt.message_id);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log(`Decrypt error: ${msg}`);
    }
  });

  wsClient.connect();
}

async function sendTestMessage(): Promise<void> {
  const state = getState();
  if (!state.account_token || !state.device_id) {
    log("Not authenticated — login first");
    return;
  }
  if (!wsClient || !wsClient.isConnected()) {
    log("WebSocket not connected");
    return;
  }

  try {
    await initCrypto();
    const devices = await api.getDevicesCached(state.account_token, 10_000, {
      onFetch: (n) => log(`Fetched devices from server count=${n}`),
    });
    const targets = devices.filter(
      (d) => d.trust_status === "trusted" && d.device_id !== state.device_id
    );

    if (targets.length === 0) {
      log("No trusted recipient devices found");
      return;
    }

    const plaintext = "hello-from-mac";
    const payloads = targets.map((d) => {
      const recipientPub = pubKeyFromB64(d.public_key);
      const { ciphertext_b64, nonce } = encryptForDevice(plaintext, recipientPub);
      return {
        to_device_id: d.device_id,
        ciphertext: ciphertext_b64,
        nonce,
      };
    });

    wsClient.sendClipboard(payloads);
    const hash = crypto.createHash("sha256").update(plaintext).digest("hex").slice(0, 16);
    log(`Sent msg hash=${hash} len=${plaintext.length} to ${targets.length} device(s)`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    log(`Send error: ${msg}`);
  }
}

async function sendClipboardContent(text: string): Promise<boolean> {
  const state = getState();
  if (!state.account_token || !state.device_id) return false;
  if (!wsClient || !wsClient.isConnected()) return false;

  try {
    await initCrypto();
    const devices = await api.getDevicesCached(state.account_token, 10_000, {
      onFetch: (n) => log(`Fetched devices from server count=${n}`),
    });
    const targets = devices.filter(
      (d) => d.trust_status === "trusted" && d.device_id !== state.device_id
    );
    if (targets.length === 0) return false;

    const payloads = targets.map((d) => {
      const recipientPub = pubKeyFromB64(d.public_key);
      const { ciphertext_b64, nonce } = encryptForDevice(text, recipientPub);
      return { to_device_id: d.device_id, ciphertext: ciphertext_b64, nonce };
    });

    const sent = wsClient.sendClipboard(payloads);
    if (!sent) return false;
    const hashPrefix = sha256hex(text).slice(0, 16);
    log(`Sent clipboard hash=${hashPrefix} len=${text.length} to ${targets.length} device(s)`);
    return true;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    log(`Clipboard send error: ${msg}`);
    return false;
  }
}

function startClipboardPolling(): void {
  if (clipboardPollTimer) return;
  clipboardPollTimer = setInterval(async () => {
    const text = clipboard.readText();
    if (!text) return;

    const hash = sha256hex(text);
    if (hash === lastLocalHash) return;
    if (hash === lastRemoteHash) return;

    upsertClipboardItem({
      source_device_label: "This Mac",
      source_device_id: getState().device_id || "local",
      text,
      hash,
      ts: Date.now(),
      direction: "local",
    });

    const ok = await sendClipboardContent(text);
    if (ok) {
      lastLocalHash = hash;
    }
  }, 500);
  log("Clipboard polling started");
}

function stopClipboardPolling(): void {
  if (clipboardPollTimer) {
    clearInterval(clipboardPollTimer);
    clipboardPollTimer = null;
    log("Clipboard polling stopped");
  }
}

function buildTrayMenu(): Menu {
  const state = getState();
  const loggedIn = !!state.account_token;
  const connected = wsClient?.isConnected() ?? false;

  return Menu.buildFromTemplate([
    {
      label: loggedIn ? `Logged in (${state.device_id?.slice(0, 8) ?? "?"})` : "Not logged in",
      enabled: false,
    },
    { type: "separator" },
    {
      label: "Login / Register",
      click: () => createLoginWindow(),
    },
    {
      label: "Send Test Message",
      enabled: loggedIn && connected,
      click: () => sendTestMessage(),
    },
    { type: "separator" },
    {
      label: "Show Logs",
      click: () => createLogsWindow(),
    },
    {
      label: "Reconnect WS",
      enabled: loggedIn && !connected,
      click: () => connectWs(),
    },
    { type: "separator" },
    {
      label: "Quit",
      click: () => {
        wsClient?.disconnect();
        app.quit();
      },
    },
  ]);
}

app.whenReady().then(async () => {
  console.log("App ready");

  loadState();
  await initCrypto();

  // Show logs window immediately so app is visible even if tray fails
  createLogsWindow();

  // Create tray with a 16x16 black circle template icon
  const icon = nativeImage.createFromDataURL(
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAMklEQVR4nGNgGMzgPxomWyNJBhHSTNAQigwgVjNOQ4aBAaQYghNQbAAxhhANyNZIXwAABnZvkUpxlIEAAAAASUVORK5CYII="
  );
  icon.setTemplateImage(true);
  console.log("Tray icon empty?", icon.isEmpty());
  tray = new Tray(icon);
  tray.setToolTip("Clipr+");
  tray.setContextMenu(buildTrayMenu());

  // Refresh menu periodically to reflect connection state
  setInterval(() => {
    if (tray) tray.setContextMenu(buildTrayMenu());
  }, 3000);

  // IPC handlers for login/register
  ipcMain.handle("auth:login", async (_event, email: string, password: string) => {
    return doAuth("login", email, password);
  });

  ipcMain.handle("auth:register", async (_event, email: string, password: string) => {
    return doAuth("register", email, password);
  });

  ipcMain.handle("copy_item_to_clipboard", (_event, itemId: string) => {
    const item = clipboardItems.find((i) => i.id === itemId);
    if (!item) return { ok: false };
    clipboard.writeText(item.text);
    lastLocalHash = item.hash;
    lastRemoteHash = item.hash;
    log(`Copied to system clipboard hash=${item.hash.slice(0, 16)}`);
    return { ok: true };
  });

  ipcMain.handle("get_clipboard_items", () => {
    return clipboardItems;
  });

  // Auto-connect if we already have a device token
  const state = getState();
  if (state.device_token) {
    log("Found existing device token — connecting WS");
    connectWs();
  }
});

app.on("window-all-closed", () => {
  // Don't quit on window close — tray app
});
