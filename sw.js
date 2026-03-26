importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAd5yylQZH0CoJbBM2_a_WfIexIoOli1wo",
  projectId: "yeoncheon-church",
  messagingSenderId: "43861878423",
  appId: "1:43861878423:web:777c02383009f9121cebd2"
});
const messaging = firebase.messaging();
messaging.onBackgroundMessage(payload => {
  const title = payload.data?.title || payload.notification?.title || '알림';
  const body  = payload.data?.body  || payload.notification?.body  || '';
  self.registration.showNotification(title, {
    body, icon: './notification-icon.png', badge: './notification-badge.png', tag: 'church-report'
  });
});

const CACHE_NAME = 'report-app-v96';
// 동적 데이터 파일은 제외 — 설치 실패 방지
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon.svg',
  './icon-192.png',
  './icon-512.png',
  './notification-icon.png',
  './notification-badge.png',
];

// 설치: 핵심 앱 셸만 캐시
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(c => c.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

// 활성화: 이전 캐시 삭제 후 즉시 클라이언트 장악
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// fetch: 네트워크 우선 → 캐시에 저장 → 실패 시 캐시
self.addEventListener('fetch', e => {
  const url = e.request.url;

  // 외부 CDN: 캐시 우선
  if (url.includes('cdnjs') || url.includes('fonts.googleapis') || url.includes('unpkg')) {
    e.respondWith(
      caches.match(e.request).then(r => r || fetch(e.request))
    );
    return;
  }

  // history.json: 네트워크 우선 (항상 최신 데이터)
  if (url.includes('history.json')) {
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

// 메시지: SKIP_WAITING 명령 수신
self.addEventListener('message', e => {
  if (e.data === 'SKIP_WAITING') self.skipWaiting();
});
