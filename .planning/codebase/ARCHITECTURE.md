# Architecture

**Analysis Date:** 2026-03-26

## Pattern Overview

**Overall:** Single-Page Application (SPA) with dual-view pattern — Report authoring app and read-only viewer app, both communicating with Firebase Realtime Database and GitHub for persistence.

**Key Characteristics:**
- Vanilla JavaScript (no framework) — Lightweight PWA suitable for mobile church use
- Dual applications: `index.html` (report writer) and `viewer.html` (statistics viewer)
- Offline-first architecture with Service Workers for both apps
- Firebase integration for real-time notifications and messaging
- GitHub as source of truth for history data with fallback local storage
- Responsive design with CSS Grid and custom variables for theming

## Layers

**Presentation (UI):**
- Purpose: Render tabbed interfaces, forms, and data visualization
- Location: Inline CSS in `index.html` and `viewer.html`, inline JavaScript for DOM manipulation
- Contains: HTML structure, CSS styling, event handlers
- Depends on: State layer for data, localStorage for user preferences
- Used by: User interactions (clicks, swipes, form submissions)

**State Management:**
- Purpose: Hold application state in memory and persist to localStorage
- Location: `state` object and related variables in `index.html` (lines 1524-1535)
- Contains: Current date, reporter name, group members and their attendance status, notes
- Depends on: localStorage API
- Used by: All render functions and form handlers

**Data Persistence:**
- Purpose: Store data locally (localStorage) and sync with remote sources
- Location: Multiple localStorage keys + Firebase RTDB + GitHub history.json
- Contains: `reportDraft`, `reportHistory`, `deletedHistoryDates`, `zonePhones`, `githubLastSync`
- Depends on: Fetch API, GitHub API (via Cloudflare Worker proxy), Firebase SDK
- Used by: Init function, sync handlers, history merge functions

**Real-Time Communication:**
- Purpose: Enable live updates between viewer and report app
- Location: Firebase Realtime Database connections in both apps
- Contains: Notifications (reports submitted), instructions (tasks from admin to report writers)
- Depends on: Firebase SDK, FCM (Firebase Cloud Messaging)
- Used by: Viewer inbox system, notification system

**Data Merging:**
- Purpose: Reconcile local edits with remote updates without conflicts
- Location: `loadHistorySeed()` (lines 1051-1116), `syncHistoryToGitHub()` (lines 1672-1765)
- Contains: Set union logic for absent names, overwrite flags for deleted records
- Depends on: State and history data structures
- Used by: App initialization and save operations

## Data Flow

**Report Submission Flow:**

1. User fills out attendance form in `index.html` with three groups (youth/young/adult) and zone members
2. User clicks Save → `saveToHistory()` called (line 1118)
3. Function transforms state into entry format (date + present/absent counts + names)
4. Entry stored in `reportHistory` array → persisted to localStorage
5. `syncHistoryToGitHub()` triggered → fetches remote history.json, merges with local changes
6. Merged data base64-encoded and sent via Cloudflare Worker to GitHub API
7. GitHub updates main branch history.json
8. Notification record created in Firebase RTDB (triggers badge in viewer)

**Viewer Load Flow:**

1. Viewer.html loads → `loadData(false)` called
2. Fetches latest history.json from GitHub raw URL
3. Groups data by date, calculates statistics (attendance %, absent counts, trends)
4. Renders cards with data visualization (bar charts, absent name chips)
5. Firebase RTDB listener watches notifications/instructions collections
6. When new notification arrives, badge appears and toast notification shows
7. User can click inbox to see message details

**History Seed Merge Flow:**

1. On app init, `loadHistorySeed()` fetches history.json
2. Compares remote dates with local `reportHistory`
3. For each remote entry:
   - If date not in local history: add it
   - If date exists: merge fields (preserve local edits, fill gaps from remote)
   - Skip dates in `deletedHistoryDates` blacklist
4. After merge, UI re-renders with combined data
5. Prevents duplicate/conflicting entries

**State Management:**

- User input → Updates `state` object in memory
- Save button → Writes to `localStorage.reportDraft` (for recovery on reload)
- Submit button → Writes to `localStorage.reportHistory` + syncs GitHub
- Delete button → Adds to `deletedHistoryDates` set to prevent remote restore
- Settings changes → Persisted to `localStorage.zonePhones`, `localStorage.githubRepo`

## Key Abstractions

**Member Object:**
- Purpose: Represents a person in youth/young/adult groups
- Examples: Used in `state.youth.members`, `state.young.members`, `state.adult.zones[].members`
- Pattern: `{ name: string, status: 'present' | 'absent', role?: 'leader' | 'inspector' | 'member' }`

**Report Entry:**
- Purpose: Single week's attendance snapshot stored in history
- Examples: Elements of `reportHistory` array
- Pattern: `{ date, youth: {present, absent, total, absentNames[]}, young: {...}, adult: {absent, zones[]}, nextWeekPlan, prayer, generalOpinion }`

**Zone:**
- Purpose: Represents adult groups organized by district
- Examples: Elements of `state.adult.zones`
- Pattern: `{ members: [{name, role, status}] }`

**Render Functions:**
- Purpose: Transform state into DOM
- Examples: `renderYouthGrid()`, `renderAdultGrid()`, `renderStats()` (report app); `renderNotifList()`, `loadData()` (viewer)
- Pattern: Query DOM by ID, set `innerHTML` or manipulate element classes

## Entry Points

**Report Writer (`index.html`):**
- Location: `index.html` lines 1-3259 (3.2K lines, single HTML file)
- Triggers: Browser load, ServiceWorker registration
- Responsibilities:
  - Initialize state from localStorage or defaults
  - Render tabbed interface with attendance forms
  - Handle form submissions and validation
  - Manage GitHub sync for history
  - Register for Firebase notifications

**Viewer (`viewer.html`):**
- Location: `viewer.html` lines 1-1194 (1.2K lines, single HTML file)
- Triggers: Browser load for separate URL
- Responsibilities:
  - Fetch and render historical statistics
  - Display real-time notification inbox
  - Send instructions to report writers via Firebase RTDB
  - Subscribe to FCM for admin messages

**Service Worker (Report) (`sw.js`):**
- Location: `sw.js` (112 lines)
- Triggers: Browser service worker registration
- Responsibilities:
  - Cache app shell (HTML, icons, manifest)
  - Intercept fetch requests with network-first strategy
  - Handle Firebase background messages (notifications)
  - Manage `history.json` network-priority strategy
  - Focus existing window or open new one when notification clicked

**Service Worker (Viewer) (`sw-viewer.js`):**
- Location: `sw-viewer.js` (78 lines)
- Triggers: Browser service worker registration (separate scope for viewer.html)
- Responsibilities:
  - Cache viewer app shell
  - Same fetch strategy as report SW
  - Route notification clicks to viewer.html specifically

## Error Handling

**Strategy:** Try-catch blocks around async operations with fallback to local data or user-facing toast notifications.

**Patterns:**
- Network failures: `loadHistorySeed()` catches fetch errors, logs to console, continues with local data
- GitHub sync failures: `syncHistoryToGitHub()` shows error toast, stores error in `sync-error.log` (server-side)
- Firebase operations: Wrapped in try-catch with user-visible error messages via `toast()` function
- Service Worker activation: Uses `skipWaiting()` to force update and claim clients immediately

## Cross-Cutting Concerns

**Logging:**
- Console.log for development (network errors, initialization steps)
- Client-side toast notifications for user-visible events
- Server-side sync.log and sync-error.log for GitHub operations

**Validation:**
- Member count validation when form is submitted
- Date field required (uses HTML5 date input)
- Text length validation for notes (implicit via textarea)
- No explicit field validation shown; relies on browser constraints

**Authentication:**
- GitHub: Token-less access via raw.githubusercontent.com (public read) + Cloudflare Worker proxy (write with token)
- Firebase: No explicit authentication; uses public Firebase config (Realtime DB is in test mode permitting anonymous writes)
- FCM: Service account key embedded in JavaScript for JWT-based FCM API access

**Offline Support:**
- Service Worker caches app shell on install
- All data saved to localStorage immediately
- history.json cached after network fetch
- App functional offline with cached data; sync attempts when network available

---

*Architecture analysis: 2026-03-26*
