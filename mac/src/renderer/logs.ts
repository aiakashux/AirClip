const clipboardListDiv = document.getElementById("clipboard-list") as HTMLDivElement;
const logsDiv = document.getElementById("logs") as HTMLDivElement;

function renderClipboardItems(items: CliprItem[]): void {
  clipboardListDiv.innerHTML = "";
  if (items.length === 0) {
    const empty = document.createElement("div");
    empty.className = "clip-empty";
    empty.textContent = "No items yet";
    clipboardListDiv.appendChild(empty);
    return;
  }

  for (const item of items) {
    const row = document.createElement("div");
    row.className = "clip-item";
    row.dataset.itemId = item.id;

    const dir = document.createElement("span");
    dir.className = `clip-dir ${item.direction}`;
    dir.textContent = item.direction === "local" ? "LOCAL" : "REMOTE";
    row.appendChild(dir);

    const source = document.createElement("span");
    source.className = "clip-source";
    source.textContent = item.source_device_label;
    row.appendChild(source);

    const text = document.createElement("span");
    text.className = "clip-text";
    text.textContent = item.text.length > 80 ? item.text.slice(0, 80) + "..." : item.text;
    row.appendChild(text);

    const time = document.createElement("span");
    time.className = "clip-time";
    time.textContent = new Date(item.ts).toLocaleTimeString();
    row.appendChild(time);

    row.addEventListener("click", async () => {
      const result = await window.clipr.copyItemToClipboard(item.id);
      if (result.ok) {
        row.classList.add("copied");
        setTimeout(() => row.classList.remove("copied"), 1000);
      }
    });

    clipboardListDiv.appendChild(row);
  }
}

// Listen for live updates from main process
window.clipr.onClipboardItemsUpdated((items: CliprItem[]) => {
  renderClipboardItems(items);
});

// Load existing items on window open
window.clipr.getClipboardItems().then((items: CliprItem[]) => {
  renderClipboardItems(items);
});

// Logs
window.clipr.onLog((msg: string) => {
  const time = new Date().toLocaleTimeString();
  const line = document.createElement("div");

  const ts = document.createElement("span");
  ts.className = "ts";
  ts.textContent = `[${time}] `;
  line.appendChild(ts);

  const content = document.createElement("span");
  content.className = "msg";
  content.textContent = msg;
  line.appendChild(content);

  logsDiv.appendChild(line);
  logsDiv.scrollTop = logsDiv.scrollHeight;
});
