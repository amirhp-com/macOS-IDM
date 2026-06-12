# Changelog

## v1.2.0 — 2026-06-12

### New Features
- **Real Pause/Resume** — engine persists per-thread progress in a `.bdm-state` sidecar; resume continues exactly where it stopped instead of restarting
- **Stop vs Pause** — Stop parks a download as Queued (keeps partial + state) until started manually
- **Transport Toolbar** — Start / Pause / Stop for the selection, plus Start All / Pause All / Stop All
- **Pop-Out Mini Widget** — chromeless floating progress capsule (animated gradient ring, comet-head glow, live speed and remaining bytes); drag anywhere, follows every Space, `⇧⌘M` or `bdm://mini`
- **Finish Tasks** — orderable per-download action chains on completion: play sound, open file, launch app, run script (via `~/Library/Application Scripts/com.amirhpcom.bdm/`), wait, turn off Wi-Fi, quit BDM, shut down Mac; configurable when adding or editing
- **Edit Downloads** — rename, change source URL, destination (moves completed files on disk), credentials, and finish tasks
- **HTTP Basic Auth** — per-download username/password, also via `bdm://add?…&user=…&pass=…`
- **Paste Detection** — copy links anywhere; activating BDM opens the Add sheet prefilled
- **Redownload** — fresh re-fetch for completed/failed items; existing file replaced atomically only on success
- **2 New View Modes** — Grid (cards) and Table (sortable columns), joining Detailed/Compact/Minimal
- **Incomplete Category** — sidebar and filter chip showing everything not yet finished
- **Status Bar** — bottom bar with live event messages, per-state counts, and total speed
- **Event Notifications** — optional notifications for start/resume and pause/stop (silent banners)
- **Per-Domain Connection Limit** — caps concurrent connections per host in the engine
- **Update Checker** — daily GitHub releases check plus "Check Now" button
- **Working Routing Rules** — editable extension/domain rules with folder + segment overrides, applied on add
- **Dock/Menu Bar Icon Choice** — show the app icon in Dock, menu bar, or both
- **App Icon** — full macOS icon set generated and assigned (Dock, notifications, Finder)

### Improvements
- Live per-segment progress: bytes count up as chunks land instead of jumping per thread
- Single instance enforced (atomic lock) and single main window (deep links never spawn duplicates)
- Adaptive light/dark palette; vibrancy-aware text fixes glass-mode readability on any wallpaper
- Settings opens from toolbar and menu bar; preview panel collapsible (`⌘⌥P`)
- Window tabbing disabled — BDM is strictly one window
- Whole UI localized through BDMLocalizer with RTL layout; Persian coverage extended
- Localizer verbose logging now persists to Console.app
- Speed limiter, max-concurrent, and battery throttle apply live from Settings

### Bug Fixes
- Fixed 98% CPU spin caused by `MenuBarExtra(isInserted:)` bound to UserDefaults
- Fixed Folders & Routing tab silently broken (Settings scene had no SwiftData container)
- Fixed downloads failing silently and items stuck "active" forever on segment errors
- Fixed Start All ignoring stopped and failed items
- Fixed finish scripts never executing under the sandbox (now via `NSUserUnixTask`)
- Fixed corrupted project file that silently excluded `MenuBarManager.swift` and `fa.json` from the build
- Fixed code signing (correct team ID, removed unused app-group entitlement)
- Fixed focus ring noise on filter chips

## v1.1.0 — 2026-03-26

### New Features
- **App Logo** — Custom dark gradient (orange → black) icon with white download symbol
- **Menu Bar Icon** — System tray icon with quick access: Show BDM, Add URLs, Pause/Resume All, Settings, Quit
- **Settings Button** — Gear icon in toolbar for quick access to preferences
- **Liquid Glass Fix** — Window transparency now works correctly; `.ultraThinMaterial` and `.glassEffect()` show desktop through
- **Persian (Farsi) Language** — Complete translation with RTL support (`fa.json`)
- **Download Scheduler** — Configure daily/weekday schedules with start/stop times, auto-pause outside hours, auto-resume
- **Scheduled Downloads** — "Scheduled" option when adding URLs; downloads run only during configured time window
- **Browser Extensions** — Chrome, Firefox, and Safari extensions for capturing downloads (separate repos)

### Improvements
- **Sidebar Toggle** — Now fully functional with `⌘⌥S` keyboard shortcut and toolbar button
- **Filter Bar** — Horizontal scroll prevents chips from breaking layout on narrow windows
- **Sort Dropdown** — Wider minimum width, text no longer clipped
- **View Mode Toggle** — Icons instead of text (list, dash, lines); more compact
- **Network Settings** — Redesigned speed limit inputs with proper alignment and descriptions
- **Language Settings** — Dynamic locale picker from bundle + Application Support, shows completion %
- **Localizer** — Now scans both app bundle and `~/Library/Application Support/BDM/Locales/` for translations

### Bug Fixes
- Fixed sidebar collapse not working (was using `.constant()` binding)
- Fixed filter chips going vertical when detail panel expanded
- Fixed sort dropdown text being cut off at 60px width
- Fixed Liquid Glass background showing as solid gray instead of translucent
- Fixed Persian language not loadable (localizer only checked Application Support, not bundle)

## v1.0.0 — 2026-03-26

### Initial Release
- Multi-thread segment download engine (2-32 segments × 2-4 threads each)
- Zero-copy assembly via sparse file + `pwrite()` at byte offset
- 3 view modes: Detailed, Compact, Minimal
- Liquid Glass UI for macOS 26 with toggle
- JSON-based localization system
- 8-tab settings window
- XPC download service
- Native notifications with actions
- SHA-256/SHA-512/MD5 checksum verification
- Auto-route downloads by file extension or domain
- Bulk URL input with preview
- Bandwidth limiter (global + battery-aware)
