import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { API } from './api';
@Injectable({providedIn:'root'})
export class PushService {
 private http=inject(HttpClient);
 async activar():Promise<string>{
  if(!('Notification' in window)||!('serviceWorker' in navigator)||!('PushManager' in window))throw new Error('Este navegador no permite Web Push. Usa Chrome o Firefox.');
  if(await Notification.requestPermission()!=='granted')throw new Error('Autoriza las notificaciones en la configuración del navegador.');
  const config:any=await firstValueFrom(this.http.get(API+'/api/notificaciones/webpush/config'));
  const registration=await navigator.serviceWorker.register(new URL('avisos-sw.js',document.baseURI),{scope:new URL('avisos/',document.baseURI).pathname});
  if(!registration.active)await new Promise<void>((resolve,reject)=>{
   const worker=registration.installing||registration.waiting;
   if(!worker)return reject(new Error('No se pudo activar el servicio de avisos.'));
   const timer=setTimeout(()=>reject(new Error('El servicio de avisos tardó demasiado. Vuelve a intentarlo.')),20000);
   worker.addEventListener('statechange',()=>{if(worker.state==='activated'){clearTimeout(timer);resolve();}});
  });
  const bytes=Uint8Array.from(atob(config.clave_publica.replace(/-/g,'+').replace(/_/g,'/')+'='.repeat((4-config.clave_publica.length%4)%4)),c=>c.charCodeAt(0));
  const subscription=await registration.pushManager.getSubscription()||await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:bytes});
  let device=localStorage.getItem('push_device');if(!device){device=crypto.randomUUID();localStorage.setItem('push_device',device);}
  await firstValueFrom(this.http.put(API+'/api/notificaciones/webpush',{...subscription.toJSON(),dispositivo:device}));
  localStorage.setItem('webpush_enabled','true');
  return 'Avisos activados. No necesitas Firebase ni claves adicionales.';
 }
}
