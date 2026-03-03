import WebSocket from "ws";
import { EventEmitter } from "events";
import { BACKEND_WS_BASE } from "./config";

export interface DeliverClipboardEvent {
  message_id: string;
  from_device_id: string;
  ciphertext: string;
  nonce: string;
  seq?: number;
}

export interface HelloEvent {
  latest_seq: number;
}

export interface ClipboardPayload {
  to_device_id: string;
  ciphertext: string;
  nonce: string;
}

export class WsClient extends EventEmitter {
  private ws: WebSocket | null = null;
  private deviceToken: string;
  private reconnectDelay = 1000;
  private maxReconnectDelay = 30000;
  private shouldReconnect = true;
  private static instanceCounter = 0;
  private instanceId: number;

  constructor(deviceToken: string) {
    super();
    this.deviceToken = deviceToken;
    this.instanceId = ++WsClient.instanceCounter;
  }

  connect(): void {
    this.emit("log", `WsClient#${this.instanceId} connect() called (shouldReconnect=${this.shouldReconnect})`);
    this.ws = new WebSocket(BACKEND_WS_BASE, {
      headers: { Authorization: `Bearer ${this.deviceToken}` },
    });

    this.ws.on("open", () => {
      this.reconnectDelay = 1000;
      this.emit("log", "WebSocket connected");
      this.emit("open");
    });

    this.ws.on("message", (data: WebSocket.Data) => {
      try {
        const msg = JSON.parse(data.toString());
        this.handleMessage(msg);
      } catch (err) {
        this.emit("log", `WS parse error: ${err}`);
      }
    });

    this.ws.on("close", (code: number, reason: Buffer) => {
      this.emit("log", `WebSocket closed: ${code} ${reason.toString()}`);
      this.emit("close");
      this.scheduleReconnect();
    });

    this.ws.on("error", (err: Error) => {
      this.emit("log", `WebSocket error: ${err.message}`);
      if (err.message.includes("403")) {
        this.shouldReconnect = false;
        this.emit("auth_forbidden");
      }
    });
  }

  private handleMessage(msg: Record<string, unknown>): void {
    switch (msg.type) {
      case "hello":
        this.emit("hello", { latest_seq: msg.latest_seq as number } as HelloEvent);
        break;
      case "deliver_clipboard":
        this.emit("deliver_clipboard", {
          message_id: msg.message_id,
          from_device_id: msg.from_device_id,
          ciphertext: msg.ciphertext,
          nonce: msg.nonce,
          seq: msg.seq as number | undefined,
        } as DeliverClipboardEvent);
        break;
      case "device_pending":
        this.emit("log", `Device pending approval: ${msg.device_id} (${msg.device_name})`);
        break;
      case "error":
        this.emit("log", `Server error: ${msg.detail || JSON.stringify(msg)}`);
        break;
      default:
        this.emit("log", `WS message: ${JSON.stringify(msg)}`);
    }
  }

  sendClipboard(payloads: ClipboardPayload[]): boolean {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      this.emit("log", "Cannot send: WebSocket not connected");
      return false;
    }
    try {
      this.ws.send(JSON.stringify({ type: "send_clipboard", payloads }));
      return true;
    } catch {
      this.emit("log", "Send failed: WebSocket error");
      return false;
    }
  }

  sendAck(messageId: string): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      this.emit("log", "Cannot ACK: WebSocket not connected");
      return;
    }
    this.ws.send(JSON.stringify({ type: "ack", message_id: messageId }));
  }

  approveDevice(targetDeviceId: string): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      this.emit("log", "Cannot approve: WebSocket not connected");
      return;
    }
    this.ws.send(JSON.stringify({ type: "approve_device", target_device_id: targetDeviceId }));
  }

  private scheduleReconnect(): void {
    if (!this.shouldReconnect) return;
    this.emit("log", `Reconnecting in ${this.reconnectDelay / 1000}s...`);
    setTimeout(() => {
      if (!this.shouldReconnect) {
        this.emit("log", `WsClient#${this.instanceId} ghost reconnect suppressed`);
        return;
      }
      this.connect();
    }, this.reconnectDelay);
    this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxReconnectDelay);
  }

  disconnect(): void {
    this.shouldReconnect = false;
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }
}
