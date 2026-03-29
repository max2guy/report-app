# Codebase Structure

**Analysis Date:** 2026-03-26

## Directory Layout

```
report-app/
├── .git/                       # Git repository
├── .claude/                    # Claude AI integration (local)
├── .planning/                  # Planning documents (this directory)
│   └── codebase/              # Architecture/structure analysis
├── index.html                  # Report writer app (3259 lines)
├── viewer.html                 # Statistics viewer app (1194 lines)
├── manifest.json               # PWA manifest for report writer
├── viewer-manifest.json        # PWA manifest for viewer
├── sw.js                        # Service Worker for report writer
├── sw-viewer.js                # Service Worker for viewer
├── history.json                # Report history database (synced with GitHub)
├── icon.svg                    # App icon source
├── icon-192.png                # PWA icon 192px
├── icon-512.png                # PWA icon 512px
├── notification-icon.png       # FCM notification icon
├── notification-badge.png      # Badge icon for FCM
├── fcm-tokens.json             # Firebase messaging tokens (generated)
├── instructions.json           # Admin instructions to report writers
├── notifications.json          # Report submission notifications
├── sync.sh                      # GitHub sync utility script
├── sync.log                     # Last sync timestamp
└── sync-error.log              # Sync errors (server-side)
```

## Directory Purposes

**Repository Root:**
- Purpose: Single-page applications with shared static assets
- Contains: Two complete HTML applications, manifests, icons, Service Workers, data files
- Key files: `index.html` (writer), `viewer.html` (viewer), `sw.js`, `sw-viewer.js`

**.git/**
- Purpose: Git version control repository
- Contains: Commit history synced with `https://github.com/max2guy/report-app.git`
- Managed by: External GitHub Actions or manual git push

**.planning/codebase/**
- Purpose: Architecture and structure documentation for development
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md (if applicable), TESTING.md (if applicable)
- Auto-generated: Yes (by GSD codebase mapper)

## Key File Locations

**Entry Points:**

- `index.html`: Report writer application — primary interface for church staff to submit weekly attendance reports
- `viewer.html`: Read-only dashboard for viewing historical statistics and managing notifications/instructions

**Configuration:**

- `manifest.json`: PWA configuration for report writer (name: "주일 사역 보고서", scope: "./", display: "standalone")
- `viewer-manifest.json`: PWA configuration for viewer (name: "사역현황")
- `sw.js`: Service Worker registration and offline strategy for report writer
- `sw-viewer.js`: Service Worker registration and offline strategy for viewer

**Core Logic:**

- `index.html` lines 1031-3259: All JavaScript for report writer (state, rendering, sync, Firebase)
- `viewer.html` lines 430-1194: All JavaScript for viewer (data loading, Firebase listeners, FCM)

**Data Storage:**

- `history.json`: JSON array of weekly report entries — source of truth synced with GitHub main branch
- `fcm-tokens.json`: List of Firebase messaging tokens for push notifications
- `instructions.json`: Admin-to-staff messaging (created/updated via Firebase RTDB)
- `notifications.json`: Report submission log (created/updated via Firebase RTDB)

**Assets:**

- `icon.svg`: Original icon artwork
- `icon-192.png`, `icon-512.png`: PWA-compliant icons for home screen
- `notification-icon.png`, `notification-badge.png`: Push notification UI assets

## Naming Conventions

**Files:**

- HTML: `index.html` (report writer), `viewer.html` (viewer) — clear purpose in name
- Service Workers: `sw.js`, `sw-viewer.js` — short, scope-specific
- Data: `history.json`, `fcm-tokens.json`, `instructions.json` — lowercase, descriptive
- Icons: `icon-{size}.png`, `notification-*.png` — size or purpose in name
- Manifests: `manifest.json`, `viewer-manifest.json` — paired with main app files

**HTML IDs:**

- Form fields: `reportDate` (input), `reporterName` (text), etc.
- Sections: `section-youth`, `section-young`, `section-adult`, `section-stats`
- Tabs: `tab-0` through `tab-4` (report writer); `tab-youth`, `tab-young`, `tab-adult` (viewer)
- Modals: `modal-export`, `modal-settings`, `inboxOverlay` (viewer)
- UI elements: `btn-{Action}` (buttons), `{name}Grid`, `{name}List` (containers)

**CSS Classes:**

- State-based: `.active` (active tab/section), `.open` (expanded accordion), `.unread` (new messages)
- Component-based: `.card` (content container), `.button` (buttons), `.stats-row` (data row)
- Layout-based: `.header`, `.main`, `.tabs`, `.section`, `.modal-overlay`
- Responsive: `.compact` (collapsed header), utility classes with mobile-first breakpoints

**JavaScript Variables:**

- State: `state` (main app state), `reportHistory` (saved entries), `deletedHistoryDates` (blacklist)
- UI state: `currentTab` (active tab index), `statsGroup` ('youth'|'young'|'adult'), `statsPeriod` ('monthly'|'yearly')
- Caches: `reportDraft` (localStorage key), `_instrList`, `_notifList` (in-memory caches from Firebase)
- Tokens/Config: `WORKER_URL`, `RAW_BASE`, `FCM_*` constants

## Where to Add New Code

**New Feature (Example: Add a new report field):**
- Primary code: Add to `state` object structure (line 1524-1535 in `index.html`)
- Render: Add form input in HTML section (around line 600-800 in `index.html`)
- Save: Add field to entry object in `saveToHistory()` (line 1118)
- Display (viewer): Add to render functions in `viewer.html` (lines 700+)
- Tests: Create `.test.html` file with manual test cases (no automated test framework used)

**New UI Component/Tab:**
- Registration: Add `<section>` in HTML with unique ID
- Tab button: Add `<button class="tab">` in header
- Logic: Add to `switchTab()` function (line 1620)
- Styling: Add CSS rules following existing pattern (mobile-first, then media queries)

**New Data Integration:**
- Firebase: Add listener to `startRTDBListeners()` (line 522 in viewer.html) for reader, or Firebase write in `index.html`
- External API: Use fetch with WORKER_URL proxy (line 1670) to avoid CORS issues
- localStorage: Follow pattern of `reportDraft`, `deletedHistoryDates` keys — parse JSON, check existence

**Utilities:**
- Shared helpers: Add inline in the HTML file (no separate module system)
- Date formatting: Follow existing pattern using `toLocaleDateString('ko-KR', opts)`
- UI feedback: Use `toast(message)` function for notifications (line ~2700)
- DOM queries: Use `document.getElementById()` or `document.querySelectorAll()` (no jQuery)

## Special Directories

**`.git/`:**
- Purpose: Version control
- Generated: Yes (automatic)
- Committed: Yes (metadata only, not data files)

**`.claude/`:**
- Purpose: Claude AI workspace integration
- Generated: Yes (automatic)
- Committed: No (local-only)

**`.planning/`:**
- Purpose: Documentation and planning files
- Generated: Yes (by GSD commands)
- Committed: Yes (reference documents)

## Special Files

**`history.json`:**
- Purpose: Source of truth for all historical reports
- Structure: JSON array of report entries with date, attendance counts, absent names, notes
- Syncing: Pushed to GitHub `main` branch via Cloudflare Worker proxy (requires token)
- Offline: Cached locally in localStorage as `reportHistory`
- Merge strategy: Local edits override remote, absent names use set union, deleted dates preserved in blacklist

**Service Worker Files:**
- Purpose: Offline-first caching strategy for both apps
- Cache keys: `report-app-v100` (writer), `viewer-v120` (viewer)
- Fetch strategy: Network-first for app files, cache-first for CDN, network-first for `history.json`

**`sync.sh`:**
- Purpose: Manual GitHub synchronization trigger (server-side)
- Usage: Called by external process when `history.json` needs explicit push
- Output: Logs to `sync.log` and `sync-error.log`

---

*Structure analysis: 2026-03-26*
