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
    body, icon: './notification-icon.png', badge: './notification-badge.png', tag: 'church-viewer'
  });
});

const CACHE = 'viewer-v93';
const SHELL = ['./viewer.html', './viewer-manifest.json', './icon-192.png', './icon-512.png', './notification-icon.png', './notification-badge.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', e => {
  if (e.data === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', e => {
  const url = e.request.url;
  // history.json — 항상 네트워크 우선
  if (url.includes('history.json')) {
    e.respondWith(
      fetch(e.request)
        .then(r => {
          if (r.ok) { const c = r.clone(); caches.open(CACHE).then(ca => ca.put(e.request, c)); }
          return r;
        })
        .catch(() => caches.match(e.request))
    );
    return;
  }
  // 나머지: 네트워크 우선 → 캐시
  e.respondWith(
    fetch(e.request)
      .then(r => {
        if (r.ok) { const c = r.clone(); caches.open(CACHE).then(ca => ca.put(e.request, c)); }
        return r;
      })
      .catch(() => caches.match(e.request))
  );
});
