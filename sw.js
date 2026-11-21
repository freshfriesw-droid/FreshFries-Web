/* Fresh Fries LUXE v38.31 — safe PWA shell & generic Web Push receiver.
   NEVER cache Supabase responses, authenticated data, order screens or credentials.
   Web Push delivery requires a separately configured VAPID sender on the server. */
'use strict';
const SHELL_CACHE = 'ff-luxe-static-v38-36-rc1';
const STATIC_ASSETS = [
  './offline.html', './manifest.webmanifest',
  './assets/ff-icon-192.png', './assets/ff-icon-512.png'
];
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(SHELL_CACHE);
    await cache.addAll(STATIC_ASSETS);
    await self.skipWaiting();
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith('ff-luxe-static-') && key !== SHELL_CACHE)
      .map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  // Application shell must remain network-only; never show stale order data offline.
  if (req.mode === 'navigate') {
    event.respondWith(fetch(req, { cache: 'no-store' }).catch(() => caches.match('./offline.html')));
    return;
  }
  if (STATIC_ASSETS.some(path => url.href === new URL(path, self.registration.scope).href)) {
    event.respondWith(caches.match(req).then(hit => hit || fetch(req)));
  }
});
self.addEventListener('push', event => {
  // Neutral notifications intentionally omit customer names, phone numbers and order details.
  event.waitUntil(self.registration.showNotification('فريش فرايز • تحديث جديد', {
    body: 'افتح النظام للاطلاع على الإشعار الجديد.',
    icon: new URL('./assets/ff-icon-192.png', self.registration.scope).href,
    badge: new URL('./assets/ff-icon-192.png', self.registration.scope).href,
    tag: 'fresh-fries-luxe-update',
    renotify: true,
    data: { path: self.registration.scope }
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const existing = windows.find(c => c.url.startsWith(self.registration.scope));
    if (existing) return existing.focus();
    return self.clients.openWindow(self.registration.scope);
  })());
});