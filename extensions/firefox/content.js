/**
 * BDM Firefox Extension — Content Script
 *
 * Detects download links on pages and intercepts clicks
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

  function getExtension(url) {
    try {
      const pathname = new URL(url, location.href).pathname;
      const match = pathname.match(/\.([a-zA-Z0-9]{1,10})$/);
      return match ? match[1].toLowerCase() : "";
    } catch {
      return "";
    }
  }

  function isDownloadLink(anchor) {
    if (!anchor || !anchor.href) return false;
    if (anchor.hasAttribute("download")) return true;
    const ext = getExtension(anchor.href);
    return DOWNLOADABLE_EXTENSIONS.has(ext);
  }

  document.addEventListener("click", (event) => {
    const anchor = event.target.closest("a[href]");
    if (!anchor) return;
    if (!isDownloadLink(anchor)) return;

    browser.runtime.sendMessage({
      type: "download-with-bdm",
      url: anchor.href,
      referrer: location.href,
    }).catch(() => {
      // Extension not available — let browser handle normally
    });

    event.preventDefault();
    event.stopPropagation();
  }, true);

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

  markDownloadLinks();

  const observer = new MutationObserver(() => {
    markDownloadLinks();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });
})();
