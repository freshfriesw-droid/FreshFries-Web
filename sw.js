/* Fresh Fries LUXE v38.31 — safe PWA shell & generic Web Push receiver.
   NEVER cache Supabase responses, authenticated data, order screens or credentials.
   Web Push delivery requires a separately configured VAPID sender on the server. */
'use strict';
const SHELL_CACHE = 'ff-luxe-static-v38-36-1-official-logo-20261121-v2';
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
  let payload={};
  try { payload=event.data?.json() || {}; } catch {
    payload={};
  }
  // Only non-sensitive metadata appears on the lock screen.
  const kinds=new Set(['new','assigned','driver_assigned','offer','ready','cancelled','late']);
  const kind=kinds.has(payload.kind)?payload.kind:'general';
  const title=typeof payload.title==='string'&&payload.title.length<=90
    ?payload.title:'🍟 فريش فرايز — تنبيه جديد';
  const body=typeof payload.body==='string'&&payload.body.length<=180
    ?payload.body:'افتح تطبيق فريش فرايز للاطلاع على التفاصيل.';
  const tag=typeof payload.tag==='string'&&/^[a-zA-Z0-9_-]{1,90}$/.test(payload.tag)
    ?payload.tag:'fresh-fries-luxe-alert';
  event.waitUntil((async()=>{
    await self.registration.showNotification(title,{
      body,
      icon:new URL('./assets/ff-icon-192.png',self.registration.scope).href,
      badge:new URL('./assets/ff-icon-192.png',self.registration.scope).href,
      tag,renotify:true,
      // Browser/OS chooses the audible alert. Custom audio cannot be played inside a SW.
      vibrate:kind==='cancelled'||kind==='late'?[220,110,220]:[140,70,140],
      requireInteraction:kind==='cancelled'||kind==='late',
      data:{path:new URL('./index.html',self.registration.scope).href,kind}
    });
    const clients=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of clients){
      client.postMessage({type:'FF_LUXE_PUSH_RECEIVED',kind});
    }
  })());
});
self.addEventListener('pushsubscriptionchange',event=>{
 event.waitUntil((async()=>{
  const clients=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  for(const client of clients)client.postMessage({type:'FF_LUXE_PUSH_SUBSCRIPTION_CHANGED'});
 })());
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const existing = windows.find(c => c.url.startsWith(self.registration.scope));
    if (existing) {
      // Background ringtone must stop when the user opens the notification,
      // without requiring a second "accept order" tap after returning to the app.
      if (existing.visibilityState !== 'visible') {
        existing.postMessage({type:'FF_LUXE_NOTIFICATION_OPENED'});
      }
      return existing.focus();
    }
    const target=new URL('./index.html',self.registration.scope);
    target.searchParams.set('ff_push_opened','1');
    return self.clients.openWindow(target.href);
  })());
});