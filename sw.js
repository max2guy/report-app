const CACHE_NAME = 'report-app-v4';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon.svg',
  './icon-192.png',
  './icon-512.png'
];

// 설치: 앱 셸 캐시
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(c => c.addAll(APP_SHELL))
  );
  // 기존 SW 즉시 교체 (대기 없이)
  self.skipWaiting();
});

// 활성화: 이전 캐시 삭제 후 즉시 클라이언트 장악
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())  // 열려있는 탭 즉시 제어
  );
});

// fetch: 네트워크 우선 → 실패 시 캐시 (항상 최신 파일 사용)
self.addEventListener('fetch', e => {
  const url = e.request.url;

  // 외부 CDN: 캐시 우선
  if (url.includes('cdnjs') || url.includes('fonts.googleapis') || url.includes('unpkg')) {
    e.respondWith(
      caches.match(e.request).then(r => r || fetch(e.request))
    );
    return;
  }

  // 앱 파일: 네트워크 우선 → 캐시에 저장 → 실패 시 캐시
  e.respondWith(
    fetch(e.request)
      .then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(e.request))
  );
});

// 메시지: SKIP_WAITING 명령 수신 (수동 강제업데이트용)
self.addEventListener('message', e => {
  if (e.data === 'SKIP_WAITING') self.skipWaiting();
});
