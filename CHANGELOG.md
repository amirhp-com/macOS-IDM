# Changelog

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
