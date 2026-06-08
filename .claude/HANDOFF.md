# report-app (주일 사역 보고서) — Codex Handoff (v0.9.11)

## 현재 상태
- 브랜치: `main`
- 최신 커밋: `4e04a6a fix: SW CDN cache - clone() before return to avoid consumed body`
- 배포: GitHub Pages (https://max2guy.github.io/report-app/)

## 방금 수정한 내용

### 문제 (3단계 디버깅으로 발견)

**1단계**: `<head>`의 CDN `<script>` 태그들이 HTML 렌더 블로킹 → body 최하단으로 이동
**2단계**: SW CDN 핸들러에 gstatic.com 추가 + 기존 핸들러가 cache miss 시 저장 안 함 수정
  - 그러나 `res.clone()`을 비동기 컨텍스트에서 호출 → body 소비 후 clone → 저장 실패
**3단계 (최종)**: `const resClone = res.clone()`을 return 전 동기적으로 호출 → 모든 CDN 스크립트 CacheStorage 저장 확인

### 해결 방법
**index.html**:
- `<head>` 14-18행의 jszip, lucide, Firebase ×3 `<script>` 태그 제거
- 동일 스크립트를 body 최하단 inline `<script>` 블록 바로 앞에 삽입
- HTML 전체 렌더링 후 CDN 스크립트 실행 (firebase.initializeApp() 실행 순서 유지)

**sw.js** (v111 → v114, 3번의 수정):
- 외부 CDN cache-first 핸들러: cdnjs/fonts.googleapis/unpkg/gstatic.com
- CORS mode fetch + `const resClone = res.clone()` 동기 호출
- CACHE_NAME: `report-app-v111` → `report-app-v114`

### 검증 결과 (브라우저 DevTools, Performance API 확인)
- CacheStorage `report-app-v114`에 CDN 5개 항목 저장됨:
  - `jszip.min.js`, `lucide.min.js`, `firebase-app-compat.js`, `firebase-messaging-compat.js`, `firebase-database-compat.js`
- 다음 로드 시 `deliveryType: "cache-storage"` (2~20ms) 로 서빙 확인
- 콘솔 에러 없음, 앱 정상 로드 확인

## 프로젝트 개요
- 연천장로교회 주일 사역 보고서 PWA
- Firebase 10.14.1 (Messaging, RTDB), jszip, lucide-icons
- 보고서 작성/제출, FCM 알림, 히스토리 관리
- CLAUDE.md: 최소 수정 원칙, pnpm 우선

## 주요 파일
- `index.html` — 앱 전체 (3583행+, inline CSS+JS 모노리스, CDN 스크립트는 body 최하단)
- `sw.js` — Service Worker (v114, network-first + CDN cache-first with CORS fetch)
- `history.json` — 히스토리 데이터 (동적)
- `sync.sh` — 히스토리 동기화 스크립트

## 다음으로 할 수 있는 작업
- inline script를 외부 .js 파일로 분리 (현재 monolith 구조)
- CDN 스크립트 로컬 호스팅 (더 강력한 캐시 독립)
- Chrome Task Manager로 실제 PWA CPU 확인 (진단 미완료 — 코드 수정은 완료)

## 빌드 & 배포
```bash
# 배포 (GitHub Pages)
git add .
git commit -m "..."
git push

# 히스토리 동기화
bash sync.sh
```
