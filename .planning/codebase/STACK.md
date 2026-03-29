# Technology Stack

**Analysis Date:** 2026-03-26

## Languages

**Primary:**
- HTML5 - Core markup for both main app and viewer
- CSS3 - Styling with CSS custom properties (variables), grid layout, flexbox
- JavaScript (Vanilla ES6+) - All client-side logic, no frameworks

**Secondary:**
- Bash - Automation scripts for git synchronization (`sync.sh`)

## Runtime

**Environment:**
- Browser-based (Web App)
- Node.js - Not required (no server-side code)
- Service Workers - Browser API for offline support and push notifications

**Package Manager:**
- None - All dependencies loaded via CDN

## Frameworks

**Core:**
- Firebase SDK 10.14.1 (compat mode) - Real-time database, messaging, authentication
  - firebase-app-compat
  - firebase-messaging-compat
  - firebase-database-compat

**UI/Icons:**
- Lucide Icons (latest via unpkg) - SVG icon library for UI elements

**Utilities:**
- JSZip 3.10.1 (via CDN) - ZIP file generation for report export

## Key Dependencies

**Critical:**
- Firebase Cloud Messaging (FCM) - Push notifications for report distribution
  - Project: `yeoncheon-church`
  - Database: `asia-southeast1.firebasedatabase.app`
  - Region-specific (Asia Southeast)

**Infrastructure:**
- Google Fonts (Noto Sans KR) - Font delivery via googleapis.com
- CDNJS (jszip) - Library CDN
- unpkg - Icon library CDN

## Configuration

**Environment:**
- No `.env` file - Configuration embedded in code
- Firebase config embedded in `index.html` and `sw.js`
- Service worker registration automatic via script tags
- PWA manifest files:
  - `manifest.json` - Main app PWA config
  - `viewer-manifest.json` - Viewer app PWA config

**Build:**
- No build process required
- Static asset delivery only
- Files:
  - `index.html` - Main reporting app (3259 lines, single-file architecture)
  - `viewer.html` - Read-only dashboard viewer
  - `sw.js` - Service worker for main app (v100 cache)
  - `sw-viewer.js` - Service worker for viewer (v120 cache)

## Local Storage

**Client-side Persistence:**
- localStorage - Stores configuration and draft data
  - `reportHistory` - JSON array of submitted reports
  - `reportDraft` - Current form state (auto-save)
  - `deletedHistoryDates` - Set of deleted report dates
  - `zonePhones` - Phone numbers for 12 zones
  - `nasAccount` - NAS server username
  - `nasPassword` - NAS server password
  - `nasUploadPath` - NAS upload directory path
  - `githubRepo` - GitHub repository reference
  - `githubLastSync` - Last sync timestamp

## Platform Requirements

**Development:**
- Browser with Service Worker support (all modern browsers)
- JavaScript ES6+ compatibility
- localStorage availability
- Web Crypto API for JWT signing (fcm access tokens)

**Production:**
- Static file hosting (GitHub Pages compatible)
- HTTPS required for:
  - Service Workers
  - Firebase SDK
  - FCM push notifications
- Browser support:
  - Chrome 51+
  - Firefox 44+
  - Safari 11.1+
  - Edge 79+

## External API Requirements

**Firebase:**
- API Key: AIzaSyAd5yylQZH0CoJbBM2_a_WfIexIoOli1wo
- Project ID: yeoncheon-church
- Database URL: https://yeoncheon-church-default-rtdb.asia-southeast1.firebasedatabase.app
- Service Account Email: firebase-adminsdk-fbsvc@yeoncheon-church.iam.gserviceaccount.com
- VAPID Key for FCM: BPTJTVQPoEC0m4fg9KgVY7dkCQfy1fQgJVnDG8OIysKxZ5f0jQm1wfgaxre3J0lNYdxG5fOs6ZurD3JgtKwSf9k

**External Proxies:**
- Cloudflare Workers proxy: `https://nas-proxy.max2guy.workers.dev`
  - Used for GitHub API write operations (rate limiting bypass)
  - Used for NAS WebDAV uploads

---

*Stack analysis: 2026-03-26*
