const CACHE_NAME = 'report-app-v3';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './icon.svg',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(c => c.addAll(ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  // 외부 CDN은 네트워크 우선
  if (e.request.url.includes('cdnjs') || e.request.url.includes('fonts.googleapis') || e.request.url.includes('unpkg')) {
    e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
    return;
  }
  // 내부 파일은 캐시 우선, 없으면 네트워크
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request).then(response => {
      // 새 응답을 캐시에 저장
      return caches.open(CACHE_NAME).then(cache => {
        cache.put(e.request, response.clone());
        return response;
      });
    }))
  );
});
