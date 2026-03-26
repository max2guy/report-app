# External Integrations

**Analysis Date:** 2026-03-26

## APIs & External Services

**Firebase Cloud Messaging (FCM):**
- Service: Push notifications
  - SDK: firebase-messaging-compat (v10.14.1)
  - Auth: Service account key in code
  - VAPID Public Key: `BPTJTVQPoEC0m4fg9KgVY7dkCQfy1fQgJVnDG8OIysKxZ5f0jQm1wfgaxre3J0lNYdxG5fOs6ZurD3JgtKwSf9k`
  - Implementation: `index.html` (lines 3100-3200), `sw.js` (lines 1-32), `sw-viewer.js` (lines 1-32)
  - Token Generation: Via OAuth2 JWT flow (crypto.subtle.sign for RS256)

**GitHub API:**
- Service: Store report history as JSON
  - Endpoint: `https://raw.githubusercontent.com/{repo}/main/history.json`
  - Default repo: `max2guy/report-app`
  - Method: REST API with git content endpoint
  - Implementation: `index.html` (lines 1668-1765, `syncHistoryToGitHub()`)
  - Auth: GitHub Personal Access Token (via Basic auth)
  - Worker proxy: `https://nas-proxy.max2guy.workers.dev/github-write`

**Google Fonts:**
- Service: Font delivery
  - Font: Noto Sans KR (weights: 300, 400, 500, 600, 700)
  - URL: `https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;600;700`

**Lucide Icons:**
- Service: SVG icon library
  - URL: `https://unpkg.com/lucide@latest/dist/umd/lucide.min.js`
  - Used for: UI buttons, navigation icons

**CDNJS:**
- Library: JSZip 3.10.1
  - URL: `https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js`
  - Purpose: ZIP file generation for report export

## Data Storage

**Databases:**
- Firebase Realtime Database
  - URL: `https://yeoncheon-church-default-rtdb.asia-southeast1.firebasedatabase.app`
  - Client: firebase-database-compat (v10.14.1)
  - Purpose: Store FCM tokens for push notification recipients
  - Implementation: `index.html` (lines 3111, token storage reference)

**File Storage:**
- GitHub Repository
  - File: `history.json`
  - Purpose: Central history storage synchronized from local storage
  - Structure: JSON array of report objects with date, content, metadata
  - Sync mechanism: Manual/automated push via Cloudflare Workers proxy

- NAS (Network-Attached Storage)
  - Protocol: WebDAV
  - Purpose: Backup report exports in ZIP format
  - Configuration stored in localStorage:
    - `nasAccount` - Username
    - `nasPassword` - Password
    - `nasUploadPath` - Target directory on NAS
  - Implementation: `index.html` (lines 2530-2570, `uploadToNAS()`)
  - Worker proxy: `https://nas-proxy.max2guy.workers.dev`

**Local Storage (Client):**
- Browser localStorage for application state persistence
  - Max size: 5-10MB depending on browser
  - Data:
    - `reportHistory` - JSON array of all submitted reports
    - `reportDraft` - Current unsaved form state (auto-save on input)
    - `deletedHistoryDates` - Deleted date tracking
    - `zonePhones` - Zone leader phone numbers (12 zones)
    - `githubRepo` - Configured GitHub repository
    - `githubLastSync` - Last synchronization timestamp

## Authentication & Identity

**Auth Provider:**
- None for end-users
- Service Account for FCM:
  - Email: `firebase-adminsdk-fbsvc@yeoncheon-church.iam.gserviceaccount.com`
  - Key: RSA private key embedded in code
  - Method: JWT + OAuth2 bearer token flow
  - Token expiry: 55 minutes cached, auto-refresh on expire

**GitHub Auth:**
- Basic authentication
  - Username: stored in localStorage as `nasAccount`
  - Password/Token: stored in localStorage as `nasPassword`
  - Used for: NAS WebDAV access and GitHub API writes

## Monitoring & Observability

**Error Tracking:**
- Console logging only
  - `console.warn()` for FCM send failures
  - `console.error()` for GitHub sync errors
  - `console.error()` for NAS upload errors

**Logs:**
- Client console (browser dev tools)
- No remote logging service
- Sync status files in local filesystem:
  - `sync.log` - Git sync logs
  - `sync-error.log` - Sync error log

## Webhooks & Callbacks

**Incoming:**
- None explicitly defined
- Firebase messaging message handlers:
  - Background message handler in service worker (sw.js, sw-viewer.js)
  - Notification click handler routes to appropriate app

**Outgoing:**
- FCM push notifications sent via:
  - Endpoint: `https://fcm.googleapis.com/v1/projects/yeoncheon-church/messages:send`
  - Method: POST with Bearer token
  - Payload: Title, body, TTL metadata
  - Implementation: `index.html` (lines 3185-3199, `sendFCMPush()`)

## CI/CD & Deployment

**Hosting:**
- Static file hosting (GitHub Pages or similar)
- Files deployed:
  - `index.html` - Main app
  - `viewer.html` - Viewer dashboard
  - `manifest.json` - PWA config
  - `viewer-manifest.json` - Viewer PWA config
  - `sw.js` - Service worker (main)
  - `sw-viewer.js` - Service worker (viewer)
  - Assets: icons (SVG, PNG), manifest files

**CI Pipeline:**
- Manual synchronization via `sync.sh`
  - Local changes → git add/commit → git push origin main
  - Auto-sync every change to GitHub
  - Pull/rebase before push to handle conflicts

## Environment Configuration

**Required env vars:**
- None in traditional sense (embedded in code)
- User-configurable via settings modal:
  - GitHub repository name
  - NAS account credentials
  - NAS upload path

**Secrets location:**
- Embedded in HTML code:
  - Firebase API key (lines 3103-3107)
  - FCM service account key (lines 3114-3141)
  - VAPID key (line 3112)
- User-provided via settings (not persisted as files):
  - GitHub token (in localStorage, not in git)
  - NAS credentials (in localStorage, not in git)

**Critical Configuration:**
- Firebase project: `yeoncheon-church`
- FCM project number: `43861878423`
- Default GitHub repo: `max2guy/report-app`
- NAS proxy worker: `https://nas-proxy.max2guy.workers.dev`

## Data Flow

**Report Submission Flow:**
1. User fills form in `index.html`
2. Draft auto-saved to localStorage (`reportDraft`)
3. Submit → JSON added to localStorage (`reportHistory`)
4. Manual sync: POST to Cloudflare Worker
5. Worker writes to GitHub via git API
6. Worker writes to NAS via WebDAV (optional)
7. History.json updated in repo

**Push Notification Flow:**
1. Report submitted
2. Author requests FCM token generation
3. Service account JWT signed with embedded private key
4. JWT → Bearer token via Google OAuth2
5. POST message to FCM API
6. FCM routes to registered device tokens
7. Service worker receives background message
8. Notification displayed + local storage updated

**Synchronization:**
- Two-way sync mechanism:
  - Pull: `history.json` from GitHub → merge with local
  - Push: local changes → GitHub via Cloudflare Worker proxy

---

*Integration audit: 2026-03-26*
