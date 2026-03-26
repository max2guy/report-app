# Coding Conventions

**Analysis Date:** 2026-03-26

## Naming Patterns

**Files:**
- Single HTML file: `index.html` - main application file
- Service workers: `sw.js`, `sw-viewer.js` - PWA service worker files
- Config files: `manifest.json`, `viewer-manifest.json` - PWA configuration

**Functions:**
- camelCase for all function names: `init()`, `saveToHistory()`, `toggleAccordion()`, `renderStats()`
- Action-based names with verbs: `render*()`, `update*()`, `toggle*()`, `set*()`, `get*()`, `add*()`, `delete*()`, `push*()`, `sync*()`
- Async functions marked with `async` keyword: `async function syncHistoryToGitHub()`, `async function loadHistorySeed()`
- Event handlers with `on*` prefix or direct `onclick` attributes in HTML: `onclick="onDateChange()"`, `onclick="toggleYouth(i)"`

**Variables:**
- camelCase for all variable names: `state`, `reportHistory`, `deletedHistoryDates`, `staffUnread`, `lastInstrId`
- Private/internal variables prefixed with underscore: `_staffInstrList`, `_fcmAccessToken`, `_fcmTokenCache`, `_fcmTokenCacheExpiry`
- Constants in UPPERCASE with underscores: `APP_VERSION`, `ZONE_MEMBERS`, `ZONE_LEADERS`, `FCM_FB_CONFIG`, `FCM_VAPID`, `FCM_SA_EMAIL`
- State object with flat property names: `state.date`, `state.reporter`, `state.department`
- Collections use plural names: `youth`, `young`, `adult` (group names); `zones` for array of zones

**Types:**
- No TypeScript used - vanilla JavaScript only
- Objects use descriptive property names: `{ date, title, reporter, zones, names, status }`
- Array items typically objects: `zones` = `[{ zone: string, leader: string, inspector: string, names: string[] }]`

**CSS Classes:**
- kebab-case for all CSS class names: `.card-header`, `.member-grid`, `.zone-acc-head`, `.stats-seg-btn`
- Utility classes: `.active`, `.present`, `.absent`, `.open`, `.disabled`, `.show`
- Element structure: `.card > .card-header > .card-body`
- Element variants: `.btn-primary`, `.btn-secondary`, `.btn-gold`, `.btn-icon`
- State classes: `.open`, `.active`, `.current`, `.sent`, `.disabled`

## Code Style

**Formatting:**
- No linter or formatter configured - code formatted manually
- Semicolons used throughout
- Single quotes in inline JavaScript: `onclick="setStatsGroup('youth')"`
- Double quotes in HTML attributes
- No spaces inside braces/parens: `{date,title,reporter}` not `{ date, title, reporter }`
- Ternary operators placed on single line for simple conditions
- Objects and arrays span multiple lines for readability

**Linting:**
- No eslint configuration detected
- No prettier configuration detected
- Code follows basic JavaScript best practices

**Comments:**
- Section headers use visual separators:
  ```javascript
  // ───────────────────────────────
  // SECTION NAME
  // ───────────────────────────────
  ```
- Inline Korean comments for clarification: `// 구역장 전화번호 (localStorage)`, `// Firebase RTDB 리스너가 갱신`
- Comments placed above code blocks explaining purpose
- No JSDoc or formal documentation comments

## Import Organization

**Not applicable** - Single HTML file project with `<script>` tags and Firebase imports in head.

**Script Loading Order (from index.html):**
1. External CDN libraries (jszip, lucide icons)
2. Firebase libraries (firebase-app, firebase-messaging, firebase-database)
3. Inline JavaScript code
4. Service worker registration
5. Application initialization

**Path Aliases:**
- No module aliases used
- All code in single global scope
- Firebase initialized with config object `FCM_FB_CONFIG`

## Error Handling

**Patterns:**
- Try-catch blocks for async operations and Firebase calls:
  ```javascript
  try {
    const res = await fetch('./history.json?v=' + Date.now());
    if (!res.ok) return;
    const seed = await res.json();
  } catch (e) {
    console.log('history.json 로드 실패 (오프라인?):', e.message);
  }
  ```
- Check for nullability with `if (!value)` or `if (!res.ok)`
- Silent failures with console.log instead of throwing:
  ```javascript
  } catch(e){ console.log('SW 등록 실패:', e); }
  ```
- Firebase operations wrapped in try-catch with toast notifications
- Graceful degradation: missing data falls back to defaults

**Error Messages:**
- User-facing errors shown via `toast()` function with emoji: `toast('🗑️ 삭제 완료')`
- Console logs for debugging with context: `console.log('history.json 로드 실패 (오프라인?):', e.message)`
- Warnings for Firebase operations: `console.warn('FCM send error', await res.json())`

## Logging

**Framework:** None - uses browser `console` object

**Patterns:**
- `console.log()` for general logging and debugging
- `console.warn()` for non-critical issues: `console.warn('FCM token save failed', e)`
- Emoji prefixes in log messages for visual distinction
- User toasts for UI feedback: `toast('📋 새 지시사항이 있습니다')`
- No log levels or structured logging

**Typical Usage:**
```javascript
console.log('SW 등록 실패:', e);
console.warn('FCM init failed', e);
toast('❌ 삭제 실패: ' + e.message);
```

## Function Design

**Size:** Functions typically 5-30 lines, with some reaching 50+ lines for complex logic
- Render functions are larger (30-50 lines) due to DOM manipulation
- Simple toggle/setter functions are 2-5 lines
- No strict function size limit enforced

**Parameters:**
- Minimal parameters: most functions take 0-2 parameters
- Group names passed as strings: `addMember('youth')`, `toggleYouth(i)`
- Arrays/objects passed for complex data
- Default parameters rarely used - defaults handled in function body

**Return Values:**
- Most functions return nothing (void) - perform DOM manipulation or state changes
- Async functions return promises: `async function syncHistoryToGitHub()`
- Utility functions may return values: `getTargetFCMToken(role)` returns token or null
- No consistent return pattern - procedural style

**Function Examples:**
```javascript
// Simple setter
function setStatsGroup(g) {
  statsGroup = g;
  renderStats();
}

// Complex async operation
async function syncHistoryToGitHub(overwrite = false) {
  try {
    // ... validation and preparation
    const auth = btoa(`${githubUser}:${githubToken}`);
    const res = await fetch(url, { method: 'PUT', headers: {...}, body: JSON.stringify(...) });
    // ... response handling
  } catch (e) {
    toast('❌ 동기화 실패: ' + e.message);
  }
}

// Render function
function renderStats() {
  const el = document.getElementById('statsChart');
  if (statsGroup === 'youth') {
    renderMonthlyStats(el);
  } else if (statsGroup === 'young') {
    // ... render logic
  }
}
```

## Module Design

**Exports:** Not applicable - single HTML file with no module system

**Global State:**
- Global `state` object holds application state:
  ```javascript
  let state = { date, reporter, department, youth: {}, young: {}, nextWeekPlan, prayer, generalOpinion };
  ```
- Global collections: `reportHistory`, `deletedHistoryDates`, `ZONE_MEMBERS`, `ZONE_LEADERS`
- Global variables for Firebase data: `_staffInstrList`, caching variables
- Global settings: `statsGroup`, `statsPeriod`, app configuration

**Organization:**
1. Section headers with visual separators
2. Related functions grouped together (render functions, state functions, sync functions)
3. Constants defined at top: `APP_VERSION = '0.9.4'`
4. State initialization in `init()` function
5. Firebase/async operations at bottom before `window.addEventListener('load')`

## Special Patterns

**localStorage Usage:**
```javascript
localStorage.setItem('lastInstrId', lastInstrId);
let lastInstrId = localStorage.getItem('lastInstrId') || '';
localStorage.setItem('youthMembers', JSON.stringify(state.youth));
```

**Firebase Real-time Database:**
```javascript
db.ref('instructions').on('value', snap => {
  const data = snap.val() || {};
  _staffInstrList = data;
});
await db.ref('notifications').push(item);
```

**DOM Manipulation:**
```javascript
// Direct innerHTML updates for rendering
el.innerHTML = list.map(i => `<div>...</div>`).join('');
// Class toggles for state
el.classList.add('open');
el.classList.remove('active');
// Inline event handlers
onclick="toggleYouth(0)"
```

**Data Merging:**
```javascript
// Merge arrays while preserving manually edited data
const mergedZones = Object.entries(zoneMap)
  .map(([zone, names]) => ({ zone, names: Array.from(names) }));
```

---

*Convention analysis: 2026-03-26*
