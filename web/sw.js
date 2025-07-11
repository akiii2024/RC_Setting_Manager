const CACHE_NAME = 'settingsheet-manager-v1';
const urlsToCache = [
  '/settingsheet_manager/',
  '/settingsheet_manager/index.html',
  '/settingsheet_manager/main.dart.js',
  '/settingsheet_manager/flutter_bootstrap.js',
  '/settingsheet_manager/favicon.png',
  '/settingsheet_manager/icons/Icon-192.png',
  '/settingsheet_manager/icons/Icon-512.png',
  '/settingsheet_manager/icons/Icon-maskable-192.png',
  '/settingsheet_manager/icons/Icon-maskable-512.png',
  '/settingsheet_manager/manifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // キャッシュから返すか、ネットワークから取得
        return response || fetch(event.request);
      })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
}); 