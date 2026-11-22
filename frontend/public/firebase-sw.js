self.addEventListener('push', event => {
  let payload;
  try { payload = event.data.json(); } catch (_) { return; }
  const message = payload.notification || payload.data || {};
  event.waitUntil(self.registration.showNotification(message.title || 'Raíces', {
    body: message.body || '', data: { url: new URL('../dashboard/notificaciones', self.registration.scope).href }
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = new URL(event.notification.data?.url || '../dashboard/notificaciones', self.registration.scope);
  if (url.origin === self.location.origin) event.waitUntil(clients.openWindow(url.href));
});
