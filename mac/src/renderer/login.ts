const emailInput = document.getElementById("email") as HTMLInputElement;
const passwordInput = document.getElementById("password") as HTMLInputElement;
const statusDiv = document.getElementById("status") as HTMLDivElement;

function setStatus(msg: string, isError: boolean) {
  statusDiv.textContent = msg;
  statusDiv.className = isError ? "error" : "success";
}

document.getElementById("btnLogin")!.addEventListener("click", async () => {
  const email = emailInput.value.trim();
  const password = passwordInput.value;
  if (!email || !password) { setStatus("Email and password required", true); return; }
  setStatus("Logging in...", false);
  const result = await window.clipr.login(email, password);
  if (result.ok) {
    setStatus("Logged in. Device registered. You can close this window.", false);
  } else {
    setStatus(result.error || "Login failed", true);
  }
});

document.getElementById("btnRegister")!.addEventListener("click", async () => {
  const email = emailInput.value.trim();
  const password = passwordInput.value;
  if (!email || !password) { setStatus("Email and password required", true); return; }
  setStatus("Registering...", false);
  const result = await window.clipr.register(email, password);
  if (result.ok) {
    setStatus("Registered. Device registered. You can close this window.", false);
  } else {
    setStatus(result.error || "Registration failed", true);
  }
});
