/**
 * BDM Chrome Extension — Background Service Worker
 *
 * Intercepts download requests from the browser and forwards them to BDM
 * via the native messaging host (com.amirhpcom.bdm).
 */

const NATIVE_HOST = "com.amirhpcom.bdm";
const DOWNLOADABLE_EXTENSIONS = [
  // Archives
  "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg", "xip",
  // Media
  "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "mp3", "flac", "aac", "wav", "ogg",
  // Documents
  "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "epub",
  // Images (large)
  "psd", "ai", "svg", "tiff",
  // Executables / Installers
  "exe", "msi", "app", "deb", "rpm", "appimage",
  // Disk images
  "img", "ipsw", "bin", "cue",
];

const MIN_CAPTURE_SIZE = 1024 * 1024; // 1 MB — skip tiny files

let captureEnabled = true;
let nativePort = null;
let bdmConnected = false;

// ---------------------------------------------------------------------------
// Storage — persist capture toggle
// ---------------------------------------------------------------------------

chrome.storage.local.get(["captureEnabled"], (result) => {
  if (result.captureEnabled !== undefined) {
    captureEnabled = result.captureEnabled;
  }
});

chrome.storage.onChanged.addListener((changes) => {
  if (changes.captureEnabled) {
    captureEnabled = changes.captureEnabled.newValue;
  }
});

// ---------------------------------------------------------------------------
// Native messaging
// ---------------------------------------------------------------------------

function connectNative() {
  if (nativePort) return;
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST);
    bdmConnected = true;
    broadcastStatus();

    nativePort.onMessage.addListener((msg) => {
      console.log("[BDM] Native message:", msg);
      if (msg.action === "status") {
        bdmConnected = msg.connected;
        broadcastStatus();
      }
    });

    nativePort.onDisconnect.addListener(() => {
      console.warn("[BDM] Native host disconnected:", chrome.runtime.lastError?.message);
      nativePort = null;
      bdmConnected = false;
      broadcastStatus();
    });
  } catch (err) {
    console.error("[BDM] Failed to connect native host:", err);
    bdmConnected = false;
    broadcastStatus();
  }
}

function sendToNative(message) {
  if (!nativePort) connectNative();
  if (nativePort) {
    nativePort.postMessage(message);
  }
}

function broadcastStatus() {
  chrome.runtime.sendMessage({
    type: "bdm-status",
    connected: bdmConnected,
    captureEnabled,
  }).catch(() => { /* popup may not be open */ });
}

// ---------------------------------------------------------------------------
// Download interception
// ---------------------------------------------------------------------------

chrome.downloads.onCreated.addListener((downloadItem) => {
  if (!captureEnabled) return;

  const url = downloadItem.url || "";
  const filename = downloadItem.filename || "";

  if (shouldCapture(url, filename, downloadItem.fileSize)) {
    // Cancel the browser download and hand off to BDM
    chrome.downloads.cancel(downloadItem.id, () => {
      chrome.downloads.erase({ id: downloadItem.id });
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
// Context menu — "Download with BDM"
// ---------------------------------------------------------------------------

chrome.contextMenus.create({
  id: "bdm-download-link",
  title: "Download with BDM",
  contexts: ["link"],
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "bdm-download-link") {
    sendToNative({
      action: "download",
      url: info.linkUrl,
      referrer: tab?.url || "",
      filename: extractFilename(info.linkUrl, ""),
      fileSize: 0,
      mimeType: "",
    });
  }
});

// ---------------------------------------------------------------------------
// Messages from popup / content scripts
// ---------------------------------------------------------------------------

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === "get-status") {
    sendResponse({ connected: bdmConnected, captureEnabled });
    return true;
  }
  if (msg.type === "set-capture") {
    captureEnabled = msg.enabled;
    chrome.storage.local.set({ captureEnabled });
    broadcastStatus();
    sendResponse({ ok: true });
    return true;
  }
  if (msg.type === "open-bdm") {
    sendToNative({ action: "open" });
    sendResponse({ ok: true });
    return true;
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
    sendResponse({ ok: true });
    return true;
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

connectNative();
