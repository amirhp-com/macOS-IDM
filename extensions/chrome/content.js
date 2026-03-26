/**
 * BDM Chrome Extension — Content Script
 *
 * Detects download links on pages and optionally intercepts clicks
 * to route them through BDM.
 */

(() => {
  "use strict";

  const DOWNLOADABLE_EXTENSIONS = new Set([
    "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg", "xip",
    "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm",
    "mp3", "flac", "aac", "wav", "ogg",
    "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "epub",
    "exe", "msi", "deb", "rpm", "appimage",
    "img", "ipsw", "bin", "psd", "ai", "tiff",
  ]);

  /**
   * Returns the file extension from a URL or empty string.
   */
  function getExtension(url) {
    try {
      const pathname = new URL(url, location.href).pathname;
      const match = pathname.match(/\.([a-zA-Z0-9]{1,10})$/);
      return match ? match[1].toLowerCase() : "";
    } catch {
      return "";
    }
  }

  /**
   * Check if a link points to a downloadable file.
   */
  function isDownloadLink(anchor) {
    if (!anchor || !anchor.href) return false;
    // Explicit download attribute
    if (anchor.hasAttribute("download")) return true;
    // Extension-based detection
    const ext = getExtension(anchor.href);
    return DOWNLOADABLE_EXTENSIONS.has(ext);
  }

  /**
   * Intercept click events on download links.
   */
  document.addEventListener("click", (event) => {
    const anchor = event.target.closest("a[href]");
    if (!anchor) return;
    if (!isDownloadLink(anchor)) return;

    // Ask background to check if capture is enabled
    chrome.runtime.sendMessage(
      {
        type: "download-with-bdm",
        url: anchor.href,
        referrer: location.href,
      },
      (response) => {
        if (chrome.runtime.lastError) {
          // Extension not available — let browser handle normally
          return;
        }
      }
    );

    event.preventDefault();
    event.stopPropagation();
  }, true);

  /**
   * Add visual indicators to detected download links (subtle).
   */
  function markDownloadLinks() {
    const links = document.querySelectorAll("a[href]");
    links.forEach((link) => {
      if (link.dataset.bdmMarked) return;
      if (isDownloadLink(link)) {
        link.dataset.bdmMarked = "true";
        link.title = link.title
          ? link.title + " [BDM will capture this download]"
          : "BDM will capture this download";
      }
    });
  }

  // Run on page load and observe DOM changes
  markDownloadLinks();

  const observer = new MutationObserver(() => {
    markDownloadLinks();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });
})();
