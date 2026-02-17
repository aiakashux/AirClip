interface CliprItem {
  id: string;
  source_device_label: string;
  source_device_id: string;
  text: string;
  hash: string;
  ts: number;
  direction: "local" | "remote";
}

interface Window {
  clipr: {
    login: (email: string, password: string) => Promise<{ ok: boolean; error?: string }>;
    register: (email: string, password: string) => Promise<{ ok: boolean; error?: string }>;
    onLog: (callback: (msg: string) => void) => void;
    onClipboardItemsUpdated: (callback: (items: CliprItem[]) => void) => void;
    copyItemToClipboard: (itemId: string) => Promise<{ ok: boolean }>;
    getClipboardItems: () => Promise<CliprItem[]>;
  };
}
