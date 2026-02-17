import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("clipr", {
  login: (email: string, password: string) => ipcRenderer.invoke("auth:login", email, password),
  register: (email: string, password: string) => ipcRenderer.invoke("auth:register", email, password),
  onLog: (callback: (msg: string) => void) => {
    ipcRenderer.on("log", (_event, msg: string) => callback(msg));
  },
  onClipboardItemsUpdated: (callback: (items: unknown[]) => void) => {
    ipcRenderer.on("clipboard_items_updated", (_event, items: unknown[]) => callback(items));
  },
  copyItemToClipboard: (itemId: string) => ipcRenderer.invoke("copy_item_to_clipboard", itemId),
  getClipboardItems: () => ipcRenderer.invoke("get_clipboard_items"),
});
