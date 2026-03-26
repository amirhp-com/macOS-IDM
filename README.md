# BlackSwan Download Manager (BDM)

<p align="center">
  <img src="logo.png" width="128" height="128" alt="BDM Logo">
</p>

A native macOS download manager that splits files into segments, downloads each segment with multiple threads in parallel, and reassembles them at full speed.

No ads. No bloat. No Electron. Just speed.

## Features

**Multi-Thread Segment Engine**
- Files split into 2-32 segments, each downloaded by 2-4 threads
- Up to 64 parallel streams per file (16 segments x 4 threads)
- Zero-copy assembly via sparse file + `pwrite()` at byte offset
- Adaptive rebalancing: slow threads cancelled and reassigned every 500ms

**3 View Modes**
- **Detailed** — full info, segment map, path, speed, ETA
- **Compact** — name + progress bar + percent + speed (single line)
- **Minimal** — ultra-dense, ~30 items visible without scroll

**macOS Native**
- Built with SwiftUI + Swift 6 strict concurrency
- Liquid Glass UI (macOS 26 Tahoe) with optional solid background
- Quick Look, Shortcuts, native notifications with actions
- XPC download service keeps downloading when app window is closed
- `bdm://` URL scheme for automation

**Smart File Routing**
- Auto-route downloads by file extension or domain
- Drag-to-reorder rules, first match wins
- Per-download folder override

**JSON Localization**
- One `.json` file per language, `{{var}}` interpolation
- RTL auto-detection, community-translated
- Missing keys fall back to English — partial translations always work

**Complete Settings**
- 8-tab settings window: General, Downloads, Folders & Routing, Network, Browser, Notifications, Language, Advanced
- Export/Import settings as a single `bdm-settings.json`
- Engine tuning: segments, threads/segment, concurrent limit, retries, bandwidth

## Requirements

- macOS 26.0 (Tahoe) or later
- Apple Silicon or Intel Mac

## Installation

1. Download `BDM-1.0.0.dmg` from [Releases](../../releases)
2. Open the DMG
3. Drag **BlackSwan Download Manager** to Applications
4. Launch from Applications or Spotlight

## Building from Source

```bash
git clone https://github.com/amirhp-com/macOS-IDM.git
cd macOS-IDM
xcodebuild -project BDM.xcodeproj -scheme BDM -configuration Release build
```

Requires Xcode 26+ with macOS 26 SDK.

## Architecture

```
BDM.app                          Main app (SwiftUI)
  └─ XPCServices/
       └─ BDMDownloader.xpc     Download engine (runs independently)

BDMShared/                       Shared Swift package (XPC protocol, types)
```

**Engine pipeline:**
```
URL → HEAD check → Segment Planner → N Segments × M Threads
    → pwrite() to sparse file → SHA-256 verify → atomic rename()
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add URLs | `⌘N` |
| Paste & add | `⌘V` |
| Pause/Resume | `Space` |
| Quick Look | `⌥Space` |
| Reveal in Finder | `⌘R` |
| Copy URL | `⌘C` |
| Copy path | `⌘⇧C` |
| Detailed view | `⌘1` |
| Compact view | `⌘2` |
| Minimal view | `⌘3` |
| Toggle sidebar | `⌘⌥S` |
| Settings | `⌘,` |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI + AppKit |
| Networking | URLSession + pwrite() |
| Concurrency | Actors + TaskGroup |
| Persistence | SwiftData |
| Localization | JSON + BDMLocalizer |
| Distribution | Direct (DMG) |

## Browser Extensions

Capture downloads from your browser directly into BDM:

| Browser | Repository |
|---------|-----------|
| Chrome | [BDM-Chrome-Extension](https://github.com/amirhp-com/BDM-Chrome-Extension) |
| Firefox | [BDM-Firefox-Extension](https://github.com/amirhp-com/BDM-Firefox-Extension) |
| Safari | [BDM-Safari-Extension](https://github.com/amirhp-com/BDM-Safari-Extension) |

Extensions communicate with BDM via native messaging. See each repo for installation instructions.

## Contributing

### Translations

BDM uses JSON-based localization. To add a language:

1. Fork this repo
2. Copy `BDM/Localization/Resources/en.json`
3. Rename to your language code (e.g., `fr.json`, `de.json`, `ja.json`)
4. Translate the values (never the keys)
5. Submit a PR

Currently available: English, فارسی (Persian/Farsi)

Partial translations are welcome — untranslated keys show English.

## License

All rights reserved. See [LICENSE](LICENSE) for details.

## Credits

Built by [@amirhp-com](https://github.com/amirhp-com)
