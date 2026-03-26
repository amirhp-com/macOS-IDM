/**
 * BDM Chrome Extension — Popup Script
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

chrome.runtime.sendMessage({ type: "get-status" }, (response) => {
  if (response) {
    updateStatus(response.connected, response.captureEnabled);
  } else {
    updateStatus(false, true);
  }
});

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "bdm-status") {
    updateStatus(msg.connected, msg.captureEnabled);
  }
});

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

captureToggle.addEventListener("change", () => {
  chrome.runtime.sendMessage({
    type: "set-capture",
    enabled: captureToggle.checked,
  });
});

openBdmBtn.addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "open-bdm" });
});
