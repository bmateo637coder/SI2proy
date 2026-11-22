import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { API } from './api';

@Injectable({ providedIn: 'root' })
export class PushService {
  private http = inject(HttpClient);
  async activar(): Promise<string> {
    if (!('Notification' in window) || !('serviceWorker' in navigator)) throw new Error('Este navegador no permite notificaciones push.');
    const config: any = await firstValueFrom(this.http.get(API + '/api/notificaciones/config'));
    if (!config.firebase?.projectId || !config.vapid_key || !config.push_configurado)
      throw new Error('Falta completar Firebase en Render: configuración web, VAPID y cuenta de servicio.');
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('Autoriza las notificaciones en la configuración del navegador.');
    const [{ initializeApp, getApps }, { getMessaging, getToken, isSupported, onMessage }] = await Promise.all([
      import('firebase/app'), import('firebase/messaging')]);
    if (!await isSupported()) throw new Error('El navegador no es compatible con FCM.');
    const app = getApps().find(a => a.name === 'raices-push') || initializeApp(config.firebase, 'raices-push');
    const registration = await navigator.serviceWorker.register(new URL('firebase-sw.js', document.baseURI), {
      scope: new URL('push/', document.baseURI).pathname });
    await new Promise<void>((resolve, reject) => {
      if (registration.active) return resolve();
      const worker = registration.installing || registration.waiting;
      if (!worker) return reject(new Error('No se pudo activar el servicio de notificaciones.'));
      const timer = setTimeout(() => reject(new Error('El servicio de notificaciones tardó demasiado.')), 20000);
      worker.addEventListener('statechange', () => {
        if (worker.state === 'activated') { clearTimeout(timer); resolve(); }
      });
    });
    const messaging = getMessaging(app);
    const token = await getToken(messaging, { vapidKey: config.vapid_key, serviceWorkerRegistration: registration });
    let device = localStorage.getItem('push_device');
    if (!device) { device = crypto.randomUUID(); localStorage.setItem('push_device', device); }
    const result: any = await firstValueFrom(this.http.put(API + '/api/notificaciones/tokens', {
      token, dispositivo: device, plataforma: 'web' }));
    localStorage.setItem('push_registration', String(result.id));
    onMessage(messaging, payload => {
      if (payload.notification) registration.showNotification(payload.notification.title || 'Raíces', {
        body: payload.notification.body, data: { url: new URL('dashboard/notificaciones', document.baseURI).href } });
    });
    return 'Push activado para esta cuenta y este navegador.';
  }
}
