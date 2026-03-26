/**
 * BDM Safari Web Extension — Background Script
 *
 * Intercepts download requests from Safari and forwards them to BDM
 * via native messaging through the Safari App Extension host.
 *
 * Safari Web Extensions communicate with the containing app via
 * browser.runtime.sendNativeMessage() instead of connectNative().
 */

const NATIVE_APP_ID = "com.amirhpcom.bdm";
const DOWNLOADABLE_EXTENSIONS = [
  "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg", "xip",
  "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "mp3", "flac", "aac", "wav", "ogg",
  "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "epub",
  "exe", "msi", "deb", "rpm", "appimage",
  "img", "ipsw", "bin", "psd", "ai", "tiff",
];

const MIN_CAPTURE_SIZE = 1024 * 1024; // 1 MB

let captureEnabled = true;
let bdmConnected = false;

// ---------------------------------------------------------------------------
// Storage — persist capture toggle
// ---------------------------------------------------------------------------

browser.storage.local.get("captureEnabled").then((result) => {
  if (result.captureEnabled !== undefined) {
    captureEnabled = result.captureEnabled;
  }
});

browser.storage.onChanged.addListener((changes) => {
  if (changes.captureEnabled) {
    captureEnabled = changes.captureEnabled.newValue;
  }
});

// ---------------------------------------------------------------------------
// Native messaging (Safari uses sendNativeMessage to the host app)
// ---------------------------------------------------------------------------

function sendToNative(message) {
  browser.runtime.sendNativeMessage(NATIVE_APP_ID, message)
    .then((response) => {
      console.log("[BDM] Native response:", response);
      if (response && response.connected !== undefined) {
        bdmConnected = response.connected;
        broadcastStatus();
      } else {
        bdmConnected = true;
        broadcastStatus();
      }
    })
    .catch((err) => {
      console.error("[BDM] Native messaging error:", err);
      bdmConnected = false;
      broadcastStatus();
    });
}

function checkConnection() {
  sendToNative({ action: "ping" });
}

function broadcastStatus() {
  browser.runtime.sendMessage({
    type: "bdm-status",
    connected: bdmConnected,
    captureEnabled,
  }).catch(() => { /* popup may not be open */ });
}

// ---------------------------------------------------------------------------
// Download interception
// ---------------------------------------------------------------------------

browser.downloads.onCreated.addListener((downloadItem) => {
  if (!captureEnabled) return;

  const url = downloadItem.url || "";
  const filename = downloadItem.filename || "";

  if (shouldCapture(url, filename, downloadItem.fileSize)) {
    browser.downloads.cancel(downloadItem.id).then(() => {
      browser.downloads.erase({ id: downloadItem.id });
    });

    sendToNative({
      action: "download",
      url,
      filename: extractFilename(url, filename),
      referrer: downloadItem.referrer || "",
      fileSize: downloadItem.fileSize || 0,
      mimeType: downloadItem.mime || "",
    });
  }
});

// ---------------------------------------------------------------------------
// Messages from popup / content scripts
// ---------------------------------------------------------------------------

browser.runtime.onMessage.addListener((msg, _sender) => {
  if (msg.type === "get-status") {
    return Promise.resolve({ connected: bdmConnected, captureEnabled });
  }
  if (msg.type === "set-capture") {
    captureEnabled = msg.enabled;
    browser.storage.local.set({ captureEnabled });
    broadcastStatus();
    return Promise.resolve({ ok: true });
  }
  if (msg.type === "open-bdm") {
    sendToNative({ action: "open" });
    return Promise.resolve({ ok: true });
  }
  if (msg.type === "download-with-bdm") {
    sendToNative({
      action: "download",
      url: msg.url,
      referrer: msg.referrer || "",
      filename: extractFilename(msg.url, ""),
      fileSize: 0,
      mimeType: "",
    });
    return Promise.resolve({ ok: true });
  }
  return false;
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function shouldCapture(url, filename, fileSize) {
  if (!url || url.startsWith("blob:") || url.startsWith("data:")) return false;
  const ext = getExtension(url) || getExtension(filename);
  if (ext && DOWNLOADABLE_EXTENSIONS.includes(ext.toLowerCase())) return true;
  if (fileSize && fileSize >= MIN_CAPTURE_SIZE) return true;
  return false;
}

function getExtension(str) {
  if (!str) return "";
  const match = str.match(/\.([a-zA-Z0-9]{1,10})(?:[?#]|$)/);
  return match ? match[1].toLowerCase() : "";
}

function extractFilename(url, fallback) {
  if (fallback) return fallback.split("/").pop() || fallback;
  try {
    const pathname = new URL(url).pathname;
    const name = pathname.split("/").pop();
    return name || "download";
  } catch {
    return "download";
  }
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

checkConnection();
