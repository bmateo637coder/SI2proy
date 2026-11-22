self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('push',event=>{
 let data={};try{data=event.data?.json()||{};}catch{}
 event.waitUntil(self.registration.showNotification(data.titulo||'Ra?ces',{
  body:data.cuerpo||'Tienes una nueva notificaci?n.',data:{url:new URL('dashboard/notificaciones',self.location).href}
 }));
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();const target=new URL('dashboard/notificaciones',self.location).href;
 event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(async clients=>{
  const client=clients.find(c=>c.url.startsWith(new URL('.',self.location).href));
  if(client){await client.navigate(target);return client.focus();}
  return self.clients.openWindow(target);
 }));
});
