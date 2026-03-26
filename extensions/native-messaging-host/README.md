# BDM Native Messaging Host

Native messaging host manifests and installer for connecting BDM browser extensions to the BDM application on macOS.

## Overview

Browser extensions use the Native Messaging API to communicate with desktop applications. This directory contains the manifest files and an installer script that sets up the connection between BDM browser extensions (Chrome, Firefox) and the BDM app.

Safari uses a different mechanism (host app) and does not require these manifests.

## Files

| File | Description |
|------|-------------|
| `com.amirhpcom.bdm.json` | Native messaging host manifest for Chrome and Chromium-based browsers |
| `com.amirhpcom.bdm-firefox.json` | Native messaging host manifest for Firefox |
| `install.sh` | Installer script that copies manifests to the correct locations |

## Quick Setup

```bash
cd extensions/native-messaging-host
chmod +x install.sh
./install.sh
```

The installer will:
1. Detect which browsers are installed
2. Copy the appropriate manifest to each browser's `NativeMessagingHosts` directory
3. Support Chrome, Chromium, Brave, Microsoft Edge, and Firefox

## Manual Installation

### Chrome / Chromium-based Browsers

Copy `com.amirhpcom.bdm.json` to:

```
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.amirhpcom.bdm.json
```

For other Chromium browsers, the paths are:
- **Chromium:** `~/Library/Application Support/Chromium/NativeMessagingHosts/`
- **Brave:** `~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/`
- **Edge:** `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/`

After installing, update the `allowed_origins` field with your extension's actual ID:

```json
"allowed_origins": [
  "chrome-extension://YOUR_ACTUAL_EXTENSION_ID/"
]
```

You can find the extension ID at `chrome://extensions/` after loading the extension.

### Firefox

Copy `com.amirhpcom.bdm-firefox.json` to:

```
~/Library/Application Support/Mozilla/NativeMessagingHosts/com.amirhpcom.bdm.json
```

Note: Firefox requires the filename to match the `name` field in the manifest (`com.amirhpcom.bdm.json`), which is why the file is renamed during installation.

The `allowed_extensions` field should contain the extension's ID as declared in `manifest.json`:

```json
"allowed_extensions": [
  "bdm@amirhp.com"
]
```

## How Native Messaging Works

1. The browser extension calls `chrome.runtime.connectNative("com.amirhpcom.bdm")` (Chrome) or `browser.runtime.connectNative("com.amirhpcom.bdm")` (Firefox)
2. The browser looks up the manifest file by name in the `NativeMessagingHosts` directory
3. The manifest specifies the path to the native host binary (`bdm-native-host`)
4. The browser launches the binary and communicates via stdin/stdout using JSON messages with a 4-byte length prefix

## Message Format

Messages are JSON objects prefixed with a 4-byte native-endian unsigned integer indicating the message length.

### Extension to BDM

```json
{
  "action": "download",
  "url": "https://example.com/file.zip",
  "filename": "file.zip",
  "referrer": "https://example.com/",
  "fileSize": 104857600,
  "mimeType": "application/zip"
}
```

### BDM to Extension

```json
{
  "action": "status",
  "connected": true,
  "version": "1.0.0"
}
```

## Troubleshooting

- **"Native host has exited"**: Ensure `bdm-native-host` exists at the path specified in the manifest and is executable (`chmod +x`)
- **"Specified native messaging host not found"**: The manifest file is not in the correct directory or the filename does not match the `name` field
- **Permission denied**: Make sure the manifest JSON file is readable and the host binary is executable
- **Chrome extension ID mismatch**: Update `allowed_origins` in the Chrome manifest with your extension's actual ID from `chrome://extensions/`

## License

MIT License. See the main [BDM repository](https://github.com/AmirhpCom/macOS-IDM) for details.
