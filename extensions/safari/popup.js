/**
 * BDM Safari Extension — Popup Script
 *
 * Uses the browser.* (WebExtension) API.
 */

const statusDot = document.getElementById("statusDot");
const statusText = document.getElementById("statusText");
const captureToggle = document.getElementById("captureToggle");
const openBdmBtn = document.getElementById("openBdm");

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

function updateStatus(connected, captureEnabled) {
  statusDot.className = "status-dot " + (connected ? "connected" : "disconnected");
  statusText.textContent = connected ? "Connected to BDM" : "BDM not running";
  captureToggle.checked = captureEnabled;
}

browser.runtime.sendMessage({ type: "get-status" }).then((response) => {
  if (response) {
    updateStatus(response.connected, response.captureEnabled);
  } else {
    updateStatus(false, true);
  }
}).catch(() => {
  updateStatus(false, true);
});

browser.runtime.onMessage.addListener((msg) => {
  if (msg.type === "bdm-status") {
    updateStatus(msg.connected, msg.captureEnabled);
  }
});

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

captureToggle.addEventListener("change", () => {
  browser.runtime.sendMessage({
    type: "set-capture",
    enabled: captureToggle.checked,
  });
});

openBdmBtn.addEventListener("click", () => {
  browser.runtime.sendMessage({ type: "open-bdm" });
});
