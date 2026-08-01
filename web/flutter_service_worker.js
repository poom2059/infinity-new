// Tombstone service worker.
// เบราว์เซอร์ที่เคยติดตั้ง service worker เวอร์ชันเก่าจะโหลดไฟล์นี้ตอนตรวจอัปเดต
// แล้วล้างแคชทั้งหมด + ถอนตัวเอง เพื่อไม่ให้เสิร์ฟบันเดิลเก่าค้างอีก
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((key) => caches.delete(key)));
      await self.registration.unregister();
      const windows = await self.clients.matchAll({ type: 'window' });
      for (const client of windows) {
        client.navigate(client.url);
      }
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
