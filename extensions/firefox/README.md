# BDM Firefox Extension

Browser extension for [BDM (Blazing Download Manager)](https://github.com/AmirhpCom/macOS-IDM) that intercepts download requests in Mozilla Firefox and sends them to BDM for accelerated, multi-segment downloading.

**Repository:** [https://github.com/amirhp-com/BDM-Firefox-Extension](https://github.com/amirhp-com/BDM-Firefox-Extension)

## Features

- Automatically captures downloads from Firefox and routes them to BDM
- Context menu integration ("Download with BDM")
- Detects downloadable file links on web pages
- Toggle capture on/off from the popup
- Connection status indicator showing whether BDM is running
- Native messaging for secure communication with BDM

## Installation

### Development (Temporary Add-on)

1. Clone this repository or download the source:
   ```bash
   git clone https://github.com/amirhp-com/BDM-Firefox-Extension.git
   ```
2. Open Firefox and navigate to `about:debugging#/runtime/this-firefox`
3. Click **Load Temporary Add-on...**
4. Select the `manifest.json` file from the extension directory
5. The BDM icon should appear in the Firefox toolbar

### Firefox Add-ons (AMO)

> Coming soon. A Firefox Add-ons listing will be available at:
> `https://addons.mozilla.org/en-US/firefox/addon/bdm/`

## Icons

Add the following icon files to the `icons/` directory from the BDM logo:

- `icon-16.png` (16x16)
- `icon-48.png` (48x48)
- `icon-128.png` (128x128)

## Native Messaging Host Setup

The extension communicates with BDM via Firefox's Native Messaging API.

1. Navigate to the `extensions/native-messaging-host/` directory in the BDM repository
2. Run the install script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
3. Restart Firefox

Alternatively, install manually:

1. Copy `com.amirhpcom.bdm-firefox.json` to:
   ```
   ~/Library/Application Support/Mozilla/NativeMessagingHosts/
   ```
2. Ensure the `path` field in the JSON points to the BDM native messaging helper binary:
   ```
   /Applications/BDM.app/Contents/Resources/bdm-native-host
   ```

## How It Works

1. **Download Interception:** When Firefox initiates a download, the background script checks if the file matches known downloadable extensions or exceeds 1 MB.

2. **Native Messaging:** If captured, the extension cancels Firefox's built-in download and sends the URL, filename, referrer, and metadata to BDM via the native messaging host (`com.amirhpcom.bdm`).

3. **Content Script:** The content script scans pages for download links and intercepts click events, sending them to BDM.

4. **Context Menu:** Right-click any link and select "Download with BDM" to manually send it to the download manager.

## Firefox-Specific Notes

- Firefox MV3 uses `background.scripts` instead of `service_worker`
- Uses `browser.*` API namespace (WebExtension standard) instead of `chrome.*`
- Context menus use `browser.menus` instead of `chrome.contextMenus`
- The `browser_specific_settings.gecko.id` field is required for native messaging
- Minimum supported version: Firefox 109

## Permissions

| Permission        | Reason                                                  |
|-------------------|---------------------------------------------------------|
| `downloads`       | Intercept and cancel browser-initiated downloads        |
| `tabs`            | Access the current tab URL for referrer information     |
| `activeTab`       | Interact with the active tab's content                  |
| `nativeMessaging` | Communicate with the BDM native messaging host          |
| `storage`         | Persist user preferences (capture toggle state)         |
| `menus`           | Add "Download with BDM" to the right-click menu         |
| `<all_urls>`      | Content script runs on all pages to detect downloads    |

## License

MIT License. See the main [BDM repository](https://github.com/AmirhpCom/macOS-IDM) for details.
