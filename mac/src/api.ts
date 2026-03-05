import { BACKEND_HTTP_BASE } from "./config";

// ---------------------------------------------------------------------------
// Typed auth error — thrown when the server returns 401 with a token-expired
// body. Callers catch this specifically to trigger session-expiry handling
// rather than treating it as a generic network error.
// ---------------------------------------------------------------------------
export class AuthExpiredError extends Error {
  constructor() {
    super("Session expired — please login again");
    this.name = "AuthExpiredError";
    // Restore prototype chain so `instanceof` works after transpilation.
    Object.setPrototypeOf(this, AuthExpiredError.prototype);
  }
}

interface AuthResponse {
  token: string;
  account_id: string;
}

export interface DeviceInfo {
  device_id: string;
  device_name: string;
  platform: string;
  public_key: string;
  trust_status: string;
  created_at: string;
  last_seen: string;
}

interface DeviceRegisterResponse extends DeviceInfo {
  token: string;
}

async function request<T>(
  method: string,
  path: string,
  body?: Record<string, unknown>,
  token?: string
): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  const res = await fetch(`${BACKEND_HTTP_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    let body = "";
    try { body = await res.text(); } catch { /* ignore read error */ }
    // Distinguish session expiry from other 401s (e.g. wrong password).
    // Primary: parse JSON and match detail field exactly.
    // Fallback: substring check if body is not valid JSON.
    if (res.status === 401) {
      let isExpired = false;
      try {
        const parsed = JSON.parse(body) as { detail?: unknown };
        const detail = typeof parsed.detail === "string" ? parsed.detail : "";
        isExpired = detail === "Token expired" || detail.includes("Token expired");
      } catch {
        isExpired = body.toLowerCase().includes("token expired");
      }
      if (isExpired) throw new AuthExpiredError();
    }
    throw new Error(`${method} ${path} failed (${res.status}): ${body}`);
  }
  return res.json() as Promise<T>;
}

export async function login(email: string, password: string): Promise<AuthResponse> {
  return request<AuthResponse>("POST", "/auth/login", { email, password });
}

export async function register(email: string, password: string): Promise<AuthResponse> {
  return request<AuthResponse>("POST", "/auth/register", { email, password });
}

export async function registerDevice(
  accountToken: string,
  deviceName: string,
  platform: string,
  publicKey_b64: string
): Promise<DeviceRegisterResponse> {
  return request<DeviceRegisterResponse>(
    "POST",
    "/devices/register",
    { device_name: deviceName, platform, public_key: publicKey_b64 },
    accountToken
  );
}

export async function getDevices(accountToken: string): Promise<DeviceInfo[]> {
  return request<DeviceInfo[]>("GET", "/devices/", undefined, accountToken);
}

// ---------------------------------------------------------------------------
// Cached wrapper for getDevices (keyed by token for account isolation)
// ---------------------------------------------------------------------------
interface CacheEntry {
  value: DeviceInfo[];
  ts: number;
  inflight: Promise<DeviceInfo[]> | null;
}

const _cache = new Map<string, CacheEntry>();

export async function getDevicesCached(
  accountToken: string,
  ttlMs = 10_000,
  opts?: { force?: boolean; onFetch?: (count: number) => void },
): Promise<DeviceInfo[]> {
  const now = Date.now();
  const force = opts?.force ?? false;
  let entry = _cache.get(accountToken);

  if (entry && !force && now - entry.ts < ttlMs) {
    return entry.value;
  }

  if (entry?.inflight) return entry.inflight;

  if (!entry) {
    entry = { value: [], ts: 0, inflight: null };
    _cache.set(accountToken, entry);
  }

  const e = entry;
  e.inflight = getDevices(accountToken)
    .then((devices) => {
      e.value = devices;
      e.ts = Date.now();
      opts?.onFetch?.(devices.length);
      return devices;
    })
    .finally(() => {
      e.inflight = null;
    });

  return e.inflight;
}

export function invalidateDevicesCache(accountToken?: string): void {
  if (accountToken) {
    _cache.delete(accountToken);
  } else {
    _cache.clear();
  }
}

// ---------------------------------------------------------------------------
// Clip history (device-token authed — for catch-up after offline)
// ---------------------------------------------------------------------------

export interface ClipHistoryItem {
  seq: bigint;
  message_id: string;
  from_device_id: string;
  ciphertext: string;
  nonce: string;
}

// Raw shape returned by JSON.parse — backend serialises seq as a JSON string
interface ClipHistoryItemRaw {
  seq: string;
  message_id: string;
  from_device_id: string;
  ciphertext: string;
  nonce: string;
}

export async function fetchClipHistory(
  deviceToken: string,
  afterSeq: bigint,
  limit = 10
): Promise<ClipHistoryItem[]> {
  // afterSeq.toString() emits digits only — no Number conversion
  const raw = await request<ClipHistoryItemRaw[]>(
    "GET",
    `/clips/?after_seq=${afterSeq.toString()}&limit=${limit}`,
    undefined,
    deviceToken
  );
  // Reject any item whose seq is not a string — coercing a number would silently lose precision
  for (const item of raw) {
    if (typeof (item as { seq: unknown }).seq !== "string") {
      throw new Error("Invalid clip history seq type; expected string");
    }
  }
  // seq is a JSON string → BigInt directly, no JS Number intermediary
  return raw.map((item) => ({ ...item, seq: BigInt(item.seq) }));
}
