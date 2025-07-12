// PWA Service Worker
const CACHE_NAME = 'rc-settings-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png'
];

// Service Workerのインストール
self.addEventListener('install', function(event) {
  console.log('Service Worker installing');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {
        console.log('Caching app resources');
        return cache.addAll(urlsToCache);
      })
  );
});

// フェッチイベントの処理
self.addEventListener('fetch', function(event) {
  console.log('Fetching:', event.request.url);
  
  // PWAのナビゲーション処理を改善
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then(function(response) {
          // 成功した場合はそのまま返す
          if (response.ok) {
            return response;
          }
          // 404エラーの場合は index.html を返す
          return caches.match('/index.html');
        })
        .catch(function() {
          // ネットワークエラーの場合は index.html を返す
          console.log('Network error, serving index.html');
          return caches.match('/index.html');
        })
    );
    return;
  }

  // 静的リソースの処理
  event.respondWith(
    caches.match(event.request)
      .then(function(response) {
        // キャッシュに存在する場合はキャッシュから返す
        if (response) {
          console.log('Serving from cache:', event.request.url);
          return response;
        }
        
        // キャッシュに存在しない場合はネットワークから取得
        return fetch(event.request).then(
          function(response) {
            // 有効なレスポンスでない場合はそのまま返す
            if(!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // レスポンスをクローンしてキャッシュに保存
            var responseToCache = response.clone();
            caches.open(CACHE_NAME)
              .then(function(cache) {
                cache.put(event.request, responseToCache);
              });

            return response;
          }
        ).catch(function() {
          // ネットワークエラーの場合、HTMLリクエストならindex.htmlを返す
          if (event.request.headers.get('accept').includes('text/html')) {
            return caches.match('/index.html');
          }
          // その他のリクエストはエラーを返す
          throw error;
        });
      })
  );
});

// アクティベートイベントの処理
self.addEventListener('activate', function(event) {
  console.log('Service Worker activating');
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          if (cacheName !== CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
}); 