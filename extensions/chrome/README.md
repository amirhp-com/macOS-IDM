# BDM Chrome Extension

Browser extension for [BDM (Blazing Download Manager)](https://github.com/AmirhpCom/macOS-IDM) that intercepts download requests in Google Chrome and sends them to BDM for accelerated, multi-segment downloading.

**Repository:** [https://github.com/amirhp-com/BDM-Chrome-Extension](https://github.com/amirhp-com/BDM-Chrome-Extension)

## Features

- Automatically captures downloads from Chrome and routes them to BDM
- Context menu integration ("Download with BDM")
- Detects downloadable file links on web pages
- Toggle capture on/off from the popup
- Connection status indicator showing whether BDM is running
- Native messaging for secure communication with BDM

## Installation

### Development (Load Unpacked)

1. Clone this repository or download the source:
   ```bash
   git clone https://github.com/amirhp-com/BDM-Chrome-Extension.git
   ```
2. Open Chrome and navigate to `chrome://extensions/`
3. Enable **Developer mode** (toggle in the top-right corner)
4. Click **Load unpacked** and select the extension directory
5. The BDM icon should appear in the Chrome toolbar

### Chrome Web Store

> Coming soon. A Chrome Web Store listing will be available at:
> `https://chrome.google.com/webstore/detail/bdm/PLACEHOLDER`

## Icons

Add the following icon files to the `icons/` directory from the BDM logo:

- `icon-16.png` (16x16)
- `icon-48.png` (48x48)
- `icon-128.png` (128x128)

## Native Messaging Host Setup

The extension communicates with BDM via Chrome's Native Messaging API. You must install the native messaging host manifest for the extension to work.

1. Navigate to the `extensions/native-messaging-host/` directory in the BDM repository
2. Run the install script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
3. Restart Chrome

Alternatively, install manually:

1. Copy `com.amirhpcom.bdm.json` to:
   ```
   ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/
   ```
2. Ensure the `path` field in the JSON points to the BDM native messaging helper binary:
   ```
   /Applications/BDM.app/Contents/Resources/bdm-native-host
   ```

## How It Works

1. **Download Interception:** When Chrome initiates a download, the background service worker checks if the file matches known downloadable extensions (archives, media, documents, installers, etc.) or exceeds 1 MB.

2. **Native Messaging:** If the download should be captured, the extension cancels Chrome's built-in download and sends the URL, filename, referrer, and metadata to BDM via the native messaging host (`com.amirhpcom.bdm`).

3. **Content Script:** The content script scans pages for download links and intercepts click events on them, sending them directly to BDM instead of letting the browser handle the download.

4. **Context Menu:** Right-click any link and select "Download with BDM" to manually send it to the download manager.

## Permissions

| Permission        | Reason                                                  |
|-------------------|---------------------------------------------------------|
| `downloads`       | Intercept and cancel browser-initiated downloads        |
| `tabs`            | Access the current tab URL for referrer information     |
| `activeTab`       | Interact with the active tab's content                  |
| `nativeMessaging` | Communicate with the BDM native messaging host          |
| `storage`         | Persist user preferences (capture toggle state)         |
| `contextMenus`    | Add "Download with BDM" to the right-click menu         |
| `<all_urls>`      | Content script runs on all pages to detect downloads    |

## Development

```bash
# Watch for changes (no build step required — plain JS)
# Just reload the extension in chrome://extensions/ after making changes
```

## License

MIT License. See the main [BDM repository](https://github.com/AmirhpCom/macOS-IDM) for details.
