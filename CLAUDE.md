<!-- GSD:project-start source:PROJECT.md -->
## Project

**BT Battery Monitor**

macOS 메뉴바 네이티브 앱으로, 블루투스 장치의 배터리 잔량을 실시간으로 모니터링한다. macOS에서 배터리 레벨을 기본 제공하지 않는 블루투스 장치(예: 기계식 키보드)도 지원하는 것이 목표이다. 사용자가 모니터링할 장치를 선택할 수 있다.

**Core Value:** 블루투스 장치의 배터리 잔량을 메뉴바에서 아이콘과 퍼센트로 한눈에 확인할 수 있어야 한다.

### Constraints

- **Tech Stack**: Swift/SwiftUI — macOS 네이티브 메뉴바 앱
- **Platform**: macOS 13+ (Ventura 이상)
- **BT Protocol**: 장치가 배터리 레벨을 BLE/HID로 노출하지 않으면 읽기 불가능할 수 있음 — 리서치 후 확인
- **Sandboxing**: App Sandbox 환경에서 블루투스 접근 권한 필요
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- HTML5 - Core markup for both main app and viewer
- CSS3 - Styling with CSS custom properties (variables), grid layout, flexbox
- JavaScript (Vanilla ES6+) - All client-side logic, no frameworks
- Bash - Automation scripts for git synchronization (`sync.sh`)
## Runtime
- Browser-based (Web App)
- Node.js - Not required (no server-side code)
- Service Workers - Browser API for offline support and push notifications
- None - All dependencies loaded via CDN
## Frameworks
- Firebase SDK 10.14.1 (compat mode) - Real-time database, messaging, authentication
- Lucide Icons (latest via unpkg) - SVG icon library for UI elements
- JSZip 3.10.1 (via CDN) - ZIP file generation for report export
## Key Dependencies
- Firebase Cloud Messaging (FCM) - Push notifications for report distribution
- Google Fonts (Noto Sans KR) - Font delivery via googleapis.com
- CDNJS (jszip) - Library CDN
- unpkg - Icon library CDN
## Configuration
- No `.env` file - Configuration embedded in code
- Firebase config embedded in `index.html` and `sw.js`
- Service worker registration automatic via script tags
- PWA manifest files:
- No build process required
- Static asset delivery only
- Files:
## Local Storage
- localStorage - Stores configuration and draft data
## Platform Requirements
- Browser with Service Worker support (all modern browsers)
- JavaScript ES6+ compatibility
- localStorage availability
- Web Crypto API for JWT signing (fcm access tokens)
- Static file hosting (GitHub Pages compatible)
- HTTPS required for:
- Browser support:
## External API Requirements
- API Key: AIzaSyAd5yylQZH0CoJbBM2_a_WfIexIoOli1wo
- Project ID: yeoncheon-church
- Database URL: https://yeoncheon-church-default-rtdb.asia-southeast1.firebasedatabase.app
- Service Account Email: firebase-adminsdk-fbsvc@yeoncheon-church.iam.gserviceaccount.com
- VAPID Key for FCM: BPTJTVQPoEC0m4fg9KgVY7dkCQfy1fQgJVnDG8OIysKxZ5f0jQm1wfgaxre3J0lNYdxG5fOs6ZurD3JgtKwSf9k
- Cloudflare Workers proxy: `https://nas-proxy.max2guy.workers.dev`
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Single HTML file: `index.html` - main application file
- Service workers: `sw.js`, `sw-viewer.js` - PWA service worker files
- Config files: `manifest.json`, `viewer-manifest.json` - PWA configuration
- camelCase for all function names: `init()`, `saveToHistory()`, `toggleAccordion()`, `renderStats()`
- Action-based names with verbs: `render*()`, `update*()`, `toggle*()`, `set*()`, `get*()`, `add*()`, `delete*()`, `push*()`, `sync*()`
- Async functions marked with `async` keyword: `async function syncHistoryToGitHub()`, `async function loadHistorySeed()`
- Event handlers with `on*` prefix or direct `onclick` attributes in HTML: `onclick="onDateChange()"`, `onclick="toggleYouth(i)"`
- camelCase for all variable names: `state`, `reportHistory`, `deletedHistoryDates`, `staffUnread`, `lastInstrId`
- Private/internal variables prefixed with underscore: `_staffInstrList`, `_fcmAccessToken`, `_fcmTokenCache`, `_fcmTokenCacheExpiry`
- Constants in UPPERCASE with underscores: `APP_VERSION`, `ZONE_MEMBERS`, `ZONE_LEADERS`, `FCM_FB_CONFIG`, `FCM_VAPID`, `FCM_SA_EMAIL`
- State object with flat property names: `state.date`, `state.reporter`, `state.department`
- Collections use plural names: `youth`, `young`, `adult` (group names); `zones` for array of zones
- No TypeScript used - vanilla JavaScript only
- Objects use descriptive property names: `{ date, title, reporter, zones, names, status }`
- Array items typically objects: `zones` = `[{ zone: string, leader: string, inspector: string, names: string[] }]`
- kebab-case for all CSS class names: `.card-header`, `.member-grid`, `.zone-acc-head`, `.stats-seg-btn`
- Utility classes: `.active`, `.present`, `.absent`, `.open`, `.disabled`, `.show`
- Element structure: `.card > .card-header > .card-body`
- Element variants: `.btn-primary`, `.btn-secondary`, `.btn-gold`, `.btn-icon`
- State classes: `.open`, `.active`, `.current`, `.sent`, `.disabled`
## Code Style
- No linter or formatter configured - code formatted manually
- Semicolons used throughout
- Single quotes in inline JavaScript: `onclick="setStatsGroup('youth')"`
- Double quotes in HTML attributes
- No spaces inside braces/parens: `{date,title,reporter}` not `{ date, title, reporter }`
- Ternary operators placed on single line for simple conditions
- Objects and arrays span multiple lines for readability
- No eslint configuration detected
- No prettier configuration detected
- Code follows basic JavaScript best practices
- Section headers use visual separators:
- Inline Korean comments for clarification: `// 구역장 전화번호 (localStorage)`, `// Firebase RTDB 리스너가 갱신`
- Comments placed above code blocks explaining purpose
- No JSDoc or formal documentation comments
## Import Organization
- No module aliases used
- All code in single global scope
- Firebase initialized with config object `FCM_FB_CONFIG`
## Error Handling
- Try-catch blocks for async operations and Firebase calls:
- Check for nullability with `if (!value)` or `if (!res.ok)`
- Silent failures with console.log instead of throwing:
- Firebase operations wrapped in try-catch with toast notifications
- Graceful degradation: missing data falls back to defaults
- User-facing errors shown via `toast()` function with emoji: `toast('🗑️ 삭제 완료')`
- Console logs for debugging with context: `console.log('history.json 로드 실패 (오프라인?):', e.message)`
- Warnings for Firebase operations: `console.warn('FCM send error', await res.json())`
## Logging
- `console.log()` for general logging and debugging
- `console.warn()` for non-critical issues: `console.warn('FCM token save failed', e)`
- Emoji prefixes in log messages for visual distinction
- User toasts for UI feedback: `toast('📋 새 지시사항이 있습니다')`
- No log levels or structured logging
## Function Design
- Render functions are larger (30-50 lines) due to DOM manipulation
- Simple toggle/setter functions are 2-5 lines
- No strict function size limit enforced
- Minimal parameters: most functions take 0-2 parameters
- Group names passed as strings: `addMember('youth')`, `toggleYouth(i)`
- Arrays/objects passed for complex data
- Default parameters rarely used - defaults handled in function body
- Most functions return nothing (void) - perform DOM manipulation or state changes
- Async functions return promises: `async function syncHistoryToGitHub()`
- Utility functions may return values: `getTargetFCMToken(role)` returns token or null
- No consistent return pattern - procedural style
## Module Design
- Global `state` object holds application state:
- Global collections: `reportHistory`, `deletedHistoryDates`, `ZONE_MEMBERS`, `ZONE_LEADERS`
- Global variables for Firebase data: `_staffInstrList`, caching variables
- Global settings: `statsGroup`, `statsPeriod`, app configuration
## Special Patterns
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Vanilla JavaScript (no framework) — Lightweight PWA suitable for mobile church use
- Dual applications: `index.html` (report writer) and `viewer.html` (statistics viewer)
- Offline-first architecture with Service Workers for both apps
- Firebase integration for real-time notifications and messaging
- GitHub as source of truth for history data with fallback local storage
- Responsive design with CSS Grid and custom variables for theming
## Layers
- Purpose: Render tabbed interfaces, forms, and data visualization
- Location: Inline CSS in `index.html` and `viewer.html`, inline JavaScript for DOM manipulation
- Contains: HTML structure, CSS styling, event handlers
- Depends on: State layer for data, localStorage for user preferences
- Used by: User interactions (clicks, swipes, form submissions)
- Purpose: Hold application state in memory and persist to localStorage
- Location: `state` object and related variables in `index.html` (lines 1524-1535)
- Contains: Current date, reporter name, group members and their attendance status, notes
- Depends on: localStorage API
- Used by: All render functions and form handlers
- Purpose: Store data locally (localStorage) and sync with remote sources
- Location: Multiple localStorage keys + Firebase RTDB + GitHub history.json
- Contains: `reportDraft`, `reportHistory`, `deletedHistoryDates`, `zonePhones`, `githubLastSync`
- Depends on: Fetch API, GitHub API (via Cloudflare Worker proxy), Firebase SDK
- Used by: Init function, sync handlers, history merge functions
- Purpose: Enable live updates between viewer and report app
- Location: Firebase Realtime Database connections in both apps
- Contains: Notifications (reports submitted), instructions (tasks from admin to report writers)
- Depends on: Firebase SDK, FCM (Firebase Cloud Messaging)
- Used by: Viewer inbox system, notification system
- Purpose: Reconcile local edits with remote updates without conflicts
- Location: `loadHistorySeed()` (lines 1051-1116), `syncHistoryToGitHub()` (lines 1672-1765)
- Contains: Set union logic for absent names, overwrite flags for deleted records
- Depends on: State and history data structures
- Used by: App initialization and save operations
## Data Flow
- User input → Updates `state` object in memory
- Save button → Writes to `localStorage.reportDraft` (for recovery on reload)
- Submit button → Writes to `localStorage.reportHistory` + syncs GitHub
- Delete button → Adds to `deletedHistoryDates` set to prevent remote restore
- Settings changes → Persisted to `localStorage.zonePhones`, `localStorage.githubRepo`
## Key Abstractions
- Purpose: Represents a person in youth/young/adult groups
- Examples: Used in `state.youth.members`, `state.young.members`, `state.adult.zones[].members`
- Pattern: `{ name: string, status: 'present' | 'absent', role?: 'leader' | 'inspector' | 'member' }`
- Purpose: Single week's attendance snapshot stored in history
- Examples: Elements of `reportHistory` array
- Pattern: `{ date, youth: {present, absent, total, absentNames[]}, young: {...}, adult: {absent, zones[]}, nextWeekPlan, prayer, generalOpinion }`
- Purpose: Represents adult groups organized by district
- Examples: Elements of `state.adult.zones`
- Pattern: `{ members: [{name, role, status}] }`
- Purpose: Transform state into DOM
- Examples: `renderYouthGrid()`, `renderAdultGrid()`, `renderStats()` (report app); `renderNotifList()`, `loadData()` (viewer)
- Pattern: Query DOM by ID, set `innerHTML` or manipulate element classes
## Entry Points
- Location: `index.html` lines 1-3259 (3.2K lines, single HTML file)
- Triggers: Browser load, ServiceWorker registration
- Responsibilities:
- Location: `viewer.html` lines 1-1194 (1.2K lines, single HTML file)
- Triggers: Browser load for separate URL
- Responsibilities:
- Location: `sw.js` (112 lines)
- Triggers: Browser service worker registration
- Responsibilities:
- Location: `sw-viewer.js` (78 lines)
- Triggers: Browser service worker registration (separate scope for viewer.html)
- Responsibilities:
## Error Handling
- Network failures: `loadHistorySeed()` catches fetch errors, logs to console, continues with local data
- GitHub sync failures: `syncHistoryToGitHub()` shows error toast, stores error in `sync-error.log` (server-side)
- Firebase operations: Wrapped in try-catch with user-visible error messages via `toast()` function
- Service Worker activation: Uses `skipWaiting()` to force update and claim clients immediately
## Cross-Cutting Concerns
- Console.log for development (network errors, initialization steps)
- Client-side toast notifications for user-visible events
- Server-side sync.log and sync-error.log for GitHub operations
- Member count validation when form is submitted
- Date field required (uses HTML5 date input)
- Text length validation for notes (implicit via textarea)
- No explicit field validation shown; relies on browser constraints
- GitHub: Token-less access via raw.githubusercontent.com (public read) + Cloudflare Worker proxy (write with token)
- Firebase: No explicit authentication; uses public Firebase config (Realtime DB is in test mode permitting anonymous writes)
- FCM: Service account key embedded in JavaScript for JWT-based FCM API access
- Service Worker caches app shell on install
- All data saved to localStorage immediately
- history.json cached after network fetch
- App functional offline with cached data; sync attempts when network available
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
