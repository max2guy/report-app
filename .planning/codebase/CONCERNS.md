# Codebase Concerns

**Analysis Date:** 2026-03-26

## Security Issues

### Exposed Firebase Credentials

**Issue:** Firebase API keys and project IDs are hardcoded directly in client-side code
- Files: `index.html` (lines 3103-3106), `viewer.html` (lines 565-568), `sw.js` (lines 5-8), `sw-viewer.js` (lines 5-8)
- Exposed data: `apiKey`, `projectId`, `messagingSenderId`, `appId` for project `yeoncheon-church`
- Impact: While Firebase keys are intentionally public for client-side apps, they're visible in version control and can be revoked if compromised
- Fix approach: Firebase security rules should restrict actual database access; consider using environment-based configuration for future updates

### Plain-Text Credentials in localStorage

**Issue:** NAS account credentials stored directly in localStorage without encryption
- Files: `index.html` (lines 975, 2332, 2517)
- Specific problem:
  - `nasPassword` stored in plain text (line 2517, 2532 usage with `btoa()` Base64 encoding)
  - Loaded from localStorage on app init (line 2332)
  - Accessible via browser DevTools and XSS attacks
- Impact: Any XSS vulnerability or malicious browser extension can steal credentials
- Current mitigation: Only in-browser; not sent to backend
- Recommendations:
  1. Remove persistent password storage; prompt user on each upload
  2. Use sessionStorage instead (clears on tab close)
  3. Consider OAuth for NAS access if protocol supports it
  4. Add HTTP-only cookie backend proxy instead of client-side auth

### GitHub Sync via Untrusted Worker

**Issue:** GitHub credentials/tokens passed through external worker endpoint
- Files: `index.html` (lines 1670, 1745)
- Worker URL: `https://nas-proxy.max2guy.workers.dev`
- Problem: Worker is controlled by third-party (max2guy); request includes sensitive headers
- Impact: Worker operator can intercept credentials, read/write to GitHub repository
- Current mitigation: Worker is owned by same person; not publicly documented API
- Recommendations:
  1. Self-host worker or use GitHub API directly if possible
  2. Document worker security model and source
  3. Rotate credentials if worker is compromised
  4. Use GitHub App instead of personal tokens for better isolation

### Base64 Encoding as Encryption

**Issue:** NAS authentication uses Base64 encoding (not encryption)
- Files: `index.html` (line 2532)
- Code: `btoa(unescape(encodeURIComponent(account + ':' + password)))`
- Impact: Easily reversible; Basic Auth over HTTPS is expected, but if MITM occurs, credentials exposed
- Current mitigation: Depends on HTTPS transport security
- Recommendations: Use token-based auth instead of credentials; refresh tokens periodically

## Tech Debt

### Monolithic HTML File

**Issue:** Both `index.html` (3259 lines) and `viewer.html` (1194 lines) contain all code in single files
- Combined: ~4,500 lines of mixed HTML, CSS, and JavaScript
- 107 functions crammed into single script context
- No module system or code organization
- Impact:
  - Impossible to test individual functions
  - Global namespace pollution
  - Hard to reason about data flow
  - Maintenance nightmare as app grows
- Fix approach:
  1. Extract logical modules (UI, state, sync, export)
  2. Use ES6 modules or bundler (Vite/Webpack)
  3. Separate concerns: HTML, styles, logic

### Global State without State Management

**Issue:** Application state scattered across globals and localStorage
- Files: `index.html` (line 1041 reportHistory, line 1540 zonePhones, scattered state object)
- Problems:
  - `let reportHistory = ...` at line 1041 — mutable global
  - `let state = { ... }` modified throughout codebase without clear update patterns
  - Multiple objects partially persisted to localStorage
  - No clear data ownership or flow
- Impact: Difficult to debug state changes; easy to create inconsistencies
- Fix approach: Implement centralized state management (even simple Redux-like pattern)

### Inline JSON Strings and Configuration

**Issue:** Hardcoded member lists, zone leaders, default data embedded in code
- Files: `index.html` has `DEFAULT_YOUTH`, `DEFAULT_YOUNG`, `ZONE_MEMBERS`, `ZONE_LEADERS` arrays
- Problem: Changes require code editing; not data-driven
- Fix approach: Move to external JSON config file or admin panel

### No Input Validation

**Issue:** User input processed with minimal validation
- Files: `index.html` name inputs, date inputs, text fields
- Risks:
  - Names with special characters may break XML generation in `esc()` function (line 2587-2592)
  - Dates not validated for correct format before storage
  - NAS paths not validated before file operations
- Current mitigation: `esc()` function escapes XML entities (line 2587-2592), but only used in document generation
- Recommendations:
  1. Validate dates on input
  2. Sanitize names before display/storage
  3. Validate NAS paths in configuration

## Data Integrity Issues

### Lost Deletion History During Sync

**Issue:** Deleted history entries not replicated across devices
- Files: `index.html` (lines 1043-1045, 1058)
- Current state: `deletedHistoryDates` Set tracks deletions locally, but doesn't sync to GitHub
- Problem: If user deletes entry on phone, opens web version on computer — deleted entry reappears from GitHub seed
- Workaround in place: `loadHistorySeed()` checks `deletedHistoryDates` Set (line 1058), but this only persists in localStorage
- Impact: User frustration; inconsistent state across devices
- Fix approach:
  1. Include `deletedHistoryDates` in GitHub-synced JSON
  2. Sync deletions bidirectionally before/after merge operations

### Name Remapping Logic Fragile

**Issue:** Hard-coded name remapping for member updates
- Files: `index.html` (lines 1570-1575)
- Current remappings:
  - '김영수' → '김영숙'
  - '류흥렬' → '류홍렬'
  - '이헌상' → '이현상'
  - '김호철' → '김효철'
- Problem: Maintained manually in code; if someone changes their name, must edit code
- Impact: Old attendance records lost if name mapping isn't added
- Fix approach: Admin panel to manage name corrections; store in persistent config

### Merge Conflicts Possible in History

**Issue:** GitHub sync uses naive merge strategy without conflict detection
- Files: `index.html` (lines 1693-1729)
- Problem: If same date edited on two devices, last-write-wins (non-deterministic)
- Current behavior: Code does merge (lines 1717-1728) but only for absentNames/zones
- Impact: Data loss if same person's attendance edited on two devices before sync
- Recommendations:
  1. Use timestamps to detect recent edits
  2. Prompt user for conflicts instead of silent merge
  3. Implement operational transformation or CRDT for conflict-free sync

## Performance Issues

### Large history.json Loaded on Init

**Issue:** Entire history JSON loaded synchronously via fetch
- Files: `index.html` (lines 1051-1116 loadHistorySeed)
- Problem: `fetch('./history.json?v=' + Date.now())` runs on every app load (line 1053)
- Current data: history.json currently ~20KB (manageable), but grows linearly with entries
- Impact: Slow initial page load if file gets large; blocks rendering until complete
- Fix approach:
  1. Implement pagination/lazy loading for statistics
  2. Cache in IndexedDB instead of fetching every time
  3. Use incremental sync (only newer entries)

### Inefficient Stats Rendering

**Issue:** Statistics recalculated and re-rendered frequently
- Files: `index.html` lines 1171-1398 (renderStats functions)
- Problem: `renderStats()` iterates entire reportHistory multiple times on each call
- Called on: app load, after save, after delete, after GitHub sync
- No memoization or diffing
- Impact: Jank on devices with large history; repeated DOM rewrites
- Fix approach:
  1. Memoize stats calculations
  2. Only update changed elements
  3. Use requestAnimationFrame for batched updates

### Service Worker Cache Strategy Inefficient

**Issue:** Service workers cache bust every request with `?v=` + Date.now()
- Files: `sw.js` (line 79), `sw-viewer.js` (line 57)
- Problem: `fetch('./history.json?v=' + Date.now())` defeats browser cache entirely
- Impact: Extra network requests even when file unchanged
- Current mitigation: Worker still caches response (lines 82-86 in sw.js), but always fetches first
- Fix approach:
  1. Use ETag/Last-Modified headers instead of URL cache-busting
  2. Implement proper HTTP cache headers on server

### DOM Manipulation with innerHTML

**Issue:** Extensive use of innerHTML for rendering
- Files: Multiple locations in `index.html` (examples: lines 1175, 1239, 1256, 1302, 1357-1358, 1831-1856, 1942-1996)
- Problem: `.innerHTML = ''` then `.innerHTML +=` in loops creates string concatenation overhead
- 20+ instances across codebase
- Impact: Slower rendering than using DocumentFragment or template literals
- Fix approach:
  1. Use `beforeend` with insertAdjacentHTML or DocumentFragment
  2. Use template strings more efficiently
  3. Implement proper templating library

## Fragile Areas

### DOCX Generation

**Issue:** Document generation tightly coupled to state shape
- Files: `index.html` (lines 2569-2850+)
- Functions: `buildDocx()`, `buildDocumentXml()`, `wParagraph()`, `wTableRow()`, `esc()`
- Problems:
  - 280+ lines of hardcoded XML templates
  - Uses `state.youth`, `state.young`, `state.adult` directly — no schema validation
  - Any change to state shape breaks document generation
  - No error handling for malformed data
- Impact: Silent failures if state is corrupt; broken DOCX files
- Test coverage: No tests
- Safe modification:
  1. Add schema validation before generation
  2. Add try-catch with detailed error messages
  3. Test with edge cases (empty zones, very long names, special characters)

### Firebase Real-time Database Listeners

**Issue:** Firebase listeners set up but error handling minimal
- Files: `index.html` (search for `db.ref` or `firebase`)
- Problems:
  - If Firebase connection drops, app silently fails to sync
  - No reconnection strategy shown
  - `console.warn()` logs but doesn't inform user
- Impact: User unaware that data isn't syncing
- Recommendations:
  1. Display connection status indicator
  2. Implement exponential backoff retry
  3. Queue changes while offline; replay on reconnect

### NAS Upload Endpoint

**Issue:** Relies on external worker proxy without fallback
- Files: `index.html` (lines 2535-2554)
- Problem: If `nas-proxy.max2guy.workers.dev` goes down, entire NAS upload fails
- No retry logic; no alternative upload methods documented
- Impact: User can't upload reports if worker is down
- Recommendations:
  1. Implement retry with exponential backoff
  2. Document fallback procedure (manual NAS access)
  3. Consider self-hosted proxy as backup

## Missing Critical Features

### No Offline Data Validation

**Issue:** Offline changes not validated until sync
- Files: `index.html` state changes throughout
- Problem: User can make invalid changes offline (e.g., negative present count)
- No validation at input time
- Impact: Invalid data committed to history, then persisted to GitHub
- Fix approach:
  1. Add input validation handlers
  2. Add state invariant checks before save
  3. Prevent obviously invalid state transitions

### No Change History/Audit Log

**Issue:** No way to see who changed what and when
- Files: `index.html` history.json structure
- Problem: Multiple users can edit same device; no attribution
- Impact: Can't track which user made a mistake
- Recommendations: Add `edited_by` and `edited_at` fields to entries

### No Concurrent Edit Prevention

**Issue:** Multiple tabs/windows can edit same draft simultaneously
- Files: `index.html` (lines 1552 localStorage.getItem('reportDraft'))
- Problem: If user opens app in two tabs, last tab to save wins
- Impact: Data loss if user switches between tabs
- Fix approach:
  1. Use SharedWorker or BroadcastChannel to sync tabs
  2. Lock draft to single tab
  3. Warn user if draft open elsewhere

### No Backup/Export Strategy

**Issue:** Only backup is GitHub-synced history; no full data export
- Files: Can download DOCX but not raw JSON
- Problem: If GitHub repo deleted, no recovery option
- Impact: Total data loss possible
- Recommendations:
  1. Add JSON export button
  2. Add periodic backup to cloud storage
  3. Document recovery procedures

## Test Coverage Gaps

### No Unit Tests

**Issue:** Zero automated tests detected
- All logic untested; 107 functions with no test harness
- High-risk functions untested:
  - `loadHistorySeed()` (data merge logic — line 1051)
  - `saveToHistory()` (state serialization — line 1118)
  - `buildDocx()` (document generation — line 2569)
  - `syncHistoryToGitHub()` (sync logic — line 1669)
  - `uploadToNAS()` (file upload — line 2515)
- Impact: Regressions go unnoticed; confidence in changes low
- Priority: High
- Recommendations:
  1. Set up Vitest or Jest
  2. Write tests for state management functions
  3. Mock external APIs (Firebase, GitHub)
  4. Add pre-commit test hook

### No Integration Tests

**Issue:** No tests for sync workflows
- Missing test scenarios:
  - Offline → online → sync flow
  - GitHub conflict merge
  - NAS upload failure → retry
  - Two-device sync race condition
- Impact: Sync bugs only discovered by users
- Recommendations:
  1. Mock Firebase and GitHub APIs
  2. Simulate network failures
  3. Test multi-tab scenarios

### No E2E Tests

**Issue:** No browser-based workflow tests
- Missing workflows:
  - Create report → upload NAS → verify file
  - Edit member attendance → sync → verify GitHub
  - Offline edit → reconnect → merge
- Recommendations: Use Playwright or Cypress for critical workflows

## Known Bugs

### Git Sync Push Rejections

**Issue:** Repeated push failures due to out-of-sync remote
- Symptoms: `error: failed to push some refs` in sync-error.log (multiple entries)
- Files: `sync-error.log` (lines 19, 31, 43)
- Trigger: Likely multiple devices pushing simultaneously without pull first
- Current state: Worker handles this via pull-before-push, but errors still logged
- Workaround: Automatic retry succeeds, but with delay

### Service Worker Update Race Condition

**Issue:** SW update notification race with app usage
- Files: `index.html` (lines 2996-3005 SW update handling)
- Problem: If user has app open when new SW activates, they're on old code
- Current mitigation: Update button to call `SKIP_WAITING` (line 110 in sw.js)
- Recommendations:
  1. Force page reload after SW activation
  2. Prevent app modifications during update
  3. Show prominent banner when update available

### Firebase RTDB Not Used Effectively

**Issue:** Firebase imported but unclear how much is actually used
- Files: `index.html` (lines 3103-3106 Firebase init)
- Problem: `firebase-database-compat.js` imported but main sync is GitHub-based
- May be legacy code; not evident from code inspection
- Impact: Unnecessary dependency; adds 20KB to bundle
- Recommendations:
  1. Audit Firebase usage
  2. Remove if not actively used
  3. Document why included if still needed

## Dependency Risks

### Unpinned CDN Dependencies

**Issue:** External libraries loaded from unpinned CDN URLs
- Files: `index.html` (lines 14-18)
- Libraries:
  - jszip: `//cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js` (line 14)
  - lucide: `//unpkg.com/lucide@latest/dist/umd/lucide.min.js` (line 15) — **@latest!**
  - Firebase: `//www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js` (line 16)
- Problem: `@latest` for lucide means random version updates
- Impact: Breaking changes possible on any page load if lucide releases incompatible version
- Recommendations:
  1. Pin all CDN versions to exact SemVer
  2. Use npm dependencies instead of CDN
  3. Set up Dependabot to track updates

### Cloudflare CDN Dependency

**Issue:** jszip loaded from Cloudflare CDN
- Problem: If CDN goes down, DOCX export breaks
- No fallback mechanism
- Recommendations:
  1. Host jszip locally or via npm
  2. Add error handling if CDN load fails

### Firebase Compat SDK

**Issue:** Using `firebase-*-compat.js` (backward compatibility layer)
- Problem: Compat SDK is legacy API; newer SDK is better
- Impact: Future deprecation; larger bundle size
- Recommendations:
  1. Upgrade to modular Firebase SDK (`firebase/app`, etc.)
  2. Remove unused Firebase services
  3. Reduce bundle size

## Scaling Limits

### LocalStorage Capacity

**Current usage:**
- `reportHistory`: Currently ~20KB (50+ entries × 400B average)
- `deletedHistoryDates`: Small set
- `zonePhones`: 12 entries × 50B
- `reportDraft`: 1KB
- `nasAccount`, `nasPassword`, etc.: 100B each

**Limit:** Most browsers: 5-10MB per origin
**Scaling:** At 400B/entry, can hold ~25,000 entries before hitting limits
**Risk:** Medium-low in near term, but growth is linear

**Fix approach:**
1. Migrate to IndexedDB for larger datasets
2. Implement data archival (move old entries to cold storage)
3. Set up alerts when approaching quota

### GitHub API Rate Limits

**Issue:** Sync calls GitHub API without rate limit handling
- Files: `index.html` (lines 1669-1765)
- Limits: GitHub allows 60 requests/hour unauthenticated, 5,000/hour authenticated
- Problem: If multiple users/devices sync frequently, could hit limits
- Current mitigation: Sync is manual + auto on upload; not continuous polling
- Impact: Sync will silently fail if rate limited
- Recommendations:
  1. Add rate limit response header checking
  2. Implement exponential backoff
  3. Show user when rate limited with retry ETA

### Service Worker Cache Growth

**Issue:** Cache not pruned; grows indefinitely
- Files: `sw.js` (line 34 `const CACHE_NAME = 'report-app-v100'`)
- Problem: New version increments cache name, but old caches cleaned by activate handler
- However: If user doesn't return for weeks, multiple cache versions could accumulate
- Current mitigation: Activate handler deletes old caches (lines 56-63 in sw.js)
- Impact: Disk space; only issue with very frequent deployments

## Summary of Priorities

**CRITICAL (Security/Data Loss):**
1. Plain-text password in localStorage → encrypt or remove
2. Input validation for document generation
3. Merge conflict detection on GitHub sync
4. Deleted entry sync across devices

**HIGH (User Experience):**
1. Add unit tests (untested is highest regression risk)
2. Implement proper state management
3. Offline data validation
4. Change history/audit log

**MEDIUM (Code Quality):**
1. Break monolithic HTML into modules
2. Improve error messaging to users
3. Cache strategy optimization
4. Service worker update handling

**LOW (Polish):**
1. Refactor innerHTML to use modern DOM APIs
2. Add connection status indicator
3. Migrate to modular Firebase SDK
4. Host CDN dependencies locally

---

*Concerns audit: 2026-03-26*
