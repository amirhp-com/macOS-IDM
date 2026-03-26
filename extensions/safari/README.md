# BDM Safari Web Extension

Browser extension for [BDM (Blazing Download Manager)](https://github.com/AmirhpCom/macOS-IDM) that intercepts download requests in Apple Safari and sends them to BDM for accelerated, multi-segment downloading.

**Repository:** [https://github.com/amirhp-com/BDM-Safari-Extension](https://github.com/amirhp-com/BDM-Safari-Extension)

> **Important:** Safari Web Extensions require an Xcode wrapper app to be built and distributed. The web extension files in this directory contain the extension logic, but they must be embedded inside a macOS app bundle using Xcode's "Safari Web Extension" template before they can be installed in Safari.

## Features

- Automatically captures downloads from Safari and routes them to BDM
- Detects downloadable file links on web pages
- Toggle capture on/off from the popup
- Connection status indicator showing whether BDM is running
- Native messaging via the host app for communication with BDM

## Installation

### Building from Source (Xcode Required)

Safari Web Extensions cannot be loaded as unpacked extensions like Chrome or Firefox. You must wrap them in a native macOS app:

1. Open Xcode and create a new project using the **Safari Web Extension App** template
2. Copy the extension files (`manifest.json`, `background.js`, `popup.html`, `popup.js`, `popup.css`, `content.js`, and `icons/`) into the generated `Resources/` directory, replacing the template files
3. Update the Xcode project's bundle identifier to `com.amirhpcom.bdm.safari-extension`
4. Build and run the project
5. Open Safari > Settings > Extensions and enable "BDM"

### Pre-built App

> Coming soon. A pre-built Safari extension app will be available via:
> - Direct download from [BDM releases](https://github.com/AmirhpCom/macOS-IDM/releases)
> - Mac App Store (pending review)

## Icons

Add the following icon files to the `icons/` directory from the BDM logo:

- `icon-16.png` (16x16)
- `icon-48.png` (48x48)
- `icon-128.png` (128x128)

## How It Works

1. **Download Interception:** When Safari initiates a download, the background script checks if the file matches known downloadable extensions or exceeds 1 MB.

2. **Native Messaging:** Safari Web Extensions use `browser.runtime.sendNativeMessage()` to communicate with the containing app, which then forwards messages to BDM. This is different from Chrome/Firefox which use `connectNative()` for a persistent connection.

3. **Content Script:** The content script scans pages for download links and intercepts click events, sending them to BDM.

## Safari-Specific Notes

- Safari Web Extensions **must** be wrapped in a native macOS/iOS app built with Xcode
- Native messaging goes through the host app, not a standalone native messaging host binary
- The `browser.*` API namespace is used (WebExtension standard)
- Safari does not support the `contextMenus`/`menus` API for extensions, so the right-click menu item is not available
- The `downloads` API has limited support in Safari; content script link interception is the primary capture mechanism
- Distribution requires either direct app distribution or the Mac App Store

## Xcode Project Structure

When creating the Xcode wrapper app, the project structure should look like:

```
BDM Safari Extension/
  BDM Safari Extension.xcodeproj
  BDM Safari Extension/          # Host app
    AppDelegate.swift
    ViewController.swift
    Main.storyboard
    Info.plist
  BDM Safari Extension Extension/ # Extension target
    Resources/
      manifest.json
      background.js
      popup.html
      popup.js
      popup.css
      content.js
      icons/
        icon-16.png
        icon-48.png
        icon-128.png
    SafariWebExtensionHandler.swift
    Info.plist
```

## Permissions

| Permission        | Reason                                                  |
|-------------------|---------------------------------------------------------|
| `downloads`       | Intercept browser-initiated downloads (limited support) |
| `tabs`            | Access the current tab URL for referrer information     |
| `activeTab`       | Interact with the active tab's content                  |
| `nativeMessaging` | Communicate with the BDM host app                       |
| `storage`         | Persist user preferences (capture toggle state)         |
| `<all_urls>`      | Content script runs on all pages to detect downloads    |

## License

MIT License. See the main [BDM repository](https://github.com/AmirhpCom/macOS-IDM) for details.
