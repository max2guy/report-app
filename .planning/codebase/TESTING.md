# Testing Patterns

**Analysis Date:** 2026-03-26

## Test Framework

**Status:** No automated testing framework detected

**Why:** Single-file vanilla JavaScript PWA with Firebase integration. Testing infrastructure not implemented.

**Testing Approach:** Manual testing only via browser developer tools and direct interaction.

## Manual Testing Areas

**Browser Console Verification:**
- Service worker registration: check `Application > Service Workers` in DevTools
- Firebase connectivity: verify `firebase.messaging()` initialization
- localStorage persistence: inspect `Application > Local Storage` for `fcmToken_reportApp`, `youthMembers`, etc.
- IndexedDB (Firebase RTDB): check `Application > IndexedDB` for cached data

**Feature Testing (Manual):**
1. **PWA Installation:**
   - Android: Install prompt appears on first visit
   - iOS: Manual "Add to Home Screen" via share menu
   - Desktop: Install button appears in header

2. **Data Persistence:**
   - Fill form → close browser → reopen → verify data persists in localStorage
   - Add members → reload → verify localStorage.getItem('youthMembers') contains data

3. **Firebase Real-time Sync:**
   - Modify `instructions` in Firebase RTDB → verify `_staffInstrList` updates via listener
   - Push notification → verify FCM listener catches `onMessage` event
   - No refresh required - `onValue` listener provides real-time updates

4. **Service Worker:**
   - Go offline → verify app loads cached shells from `SHELL` array
   - Access offline-available endpoints: `./index.html`, `./manifest.json`, icons

5. **Rendering:**
   - Switch tabs → verify only active `.section` shows
   - Toggle accordion → verify `.zone-acc-body.open` displays
   - Add member → verify grid re-renders with new chip element

## Code Quality Verification (Manual)

**Console Error Checking:**
```javascript
// Run in browser console to check for errors
console.log('reportHistory:', reportHistory);
console.log('state:', state);
console.log('Service Worker:', navigator.serviceWorker.controller);
```

**Critical Functions to Verify:**
- `loadHistorySeed()` - History merging logic, try-catch handling
- `syncHistoryToGitHub()` - GitHub API auth, blob creation, overwrite handling
- `getFCMAccessToken()` - JWT generation for FCM auth
- `renderStats()- DOM manipulation correctness

**Debugging Patterns in Code:**
- All Firebase operations have try-catch with `console.log()` feedback
- Network calls check `if (!res.ok)` before processing
- Silent failures logged to console, toast notifications for user
- Merging logic validates data structure before assignment

## Data Flow Verification

**Typical User Workflow (Testable Sequence):**

1. **Load Day:**
   ```
   init() → set date from localStorage
   → loadHistorySeed() → fetch history.json
   → render forms from state
   ```

2. **Add Member:**
   ```
   addMember('youth')
   → state.youth.members.push(...)
   → updateYouthStats()
   → renderYouthGrid()
   → DOM updates
   ```

3. **Save Report:**
   ```
   button.onclick → saveToHistory()
   → state saved to reportHistory array
   → localStorage updated
   → saveDeletedDates() stores blacklist
   → toast shows success
   ```

4. **Sync to GitHub:**
   ```
   syncHistoryToGitHub()
   → create blob from history.json
   → getFCMAccessToken() for auth
   → POST to GitHub API
   → verify commit created in repo
   ```

5. **Firebase Real-time Sync:**
   ```
   startInstrListener()
   → db.ref('instructions').on('value')
   → _staffInstrList updates
   → renderStaffInstrList() called
   → UI reflects changes without reload
   ```

## Error Scenarios to Test

**Network Errors:**
```javascript
// Test by disabling network or mocking fetch failures
try {
  const res = await fetch('./history.json');
  if (!res.ok) return; // Silent failure
} catch (e) {
  console.log('history.json 로드 실패 (오프라인?):', e.message);
}
```

**Firebase Errors:**
```javascript
try {
  await db.ref('notifications').push(item);
} catch(e) {
  console.log('보고서 알림 전송 실패:', e.message);
}
```

**Validation Errors:**
- Empty date field → `onDateChange()` may fail silently
- Missing reporter name → still allows save (no validation)
- Duplicate member names → allowed, may cause confusion

## Testing Utilities

**Browser Console Test Commands:**
```javascript
// Check current state
console.log({state, reportHistory, ZONE_MEMBERS})

// Test member operations
addMember('youth'); renderYouthGrid();

// Test localStorage
localStorage.setItem('test', 'value');
console.log(localStorage.getItem('test'));

// Test Firebase
db.ref('test').set({data: 'value'}).then(() => console.log('Success'));

// Test rendering
renderStats(); renderSMSModalBody();

// Clear data
localStorage.clear(); location.reload();
```

**Checking for Memory Leaks:**
- Firebase listeners: check if `.off()` called on unload
- DOM references: check for circular references via Chrome DevTools Memory tab
- Note: Current code uses `.on('value')` without `.off()` - potential leak

## Smoke Testing Checklist

**Pre-release Checks:**
- [ ] PWA installs on Android/iOS
- [ ] All tabs load without console errors
- [ ] Members persist after reload
- [ ] Firebase listeners active (check DevTools > Network > WebSocket)
- [ ] Service worker cached resources load offline
- [ ] GitHub sync creates commits successfully
- [ ] FCM push notifications received
- [ ] SMS queue processes without errors
- [ ] Statistics render correctly for all period/group combinations
- [ ] Form fields serialize correctly to localStorage

**Critical Paths (Must Work):**
1. Load report form with history
2. Add member → save → reload → verify persisted
3. Sync to GitHub → verify commit in repo
4. Receive Firebase notification → verify appears in inbox
5. Send SMS → verify queued and processable

## Known Testing Gaps

**No Unit Tests:**
- No test for member deduplication logic
- No test for zone merging during seed load
- No test for statistics calculation
- No test for localStorage serialization
- No test for Firebase RTDB data structure

**No Integration Tests:**
- GitHub API integration never tested in CI
- Firebase RTDB integration relies on live Firebase project
- SMS queue integrates with external API (no mock)

**No E2E Tests:**
- User workflows tested only manually
- PWA installation tested manually
- Cross-browser testing not automated

**Recommendations for Future:**
- Add Jest or Vitest for unit tests (would require bundler like Webpack/Vite)
- Add Firebase Emulator Suite for local testing
- Add E2E tests with Playwright or Cypress
- Add pre-commit hooks to catch errors early

---

*Testing analysis: 2026-03-26*
