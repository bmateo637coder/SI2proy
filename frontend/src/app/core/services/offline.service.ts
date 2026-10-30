import { Injectable, signal, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { firstValueFrom, timeout } from 'rxjs';
import { AuthService } from './auth.service';
import { environment } from '../../../environments/environment';

export interface LocalOperation {
  key: string;
  scope: string;
  kind: 'operation';
  payload: any;
  estado: 'local' | 'enviando' | 'pendiente' | 'confirmada' | 'rechazada' | 'conflicto' | 'cancelada';
  motivo?: string;
  resultado?: any;
}

@Injectable({ providedIn: 'root' })
export class OfflineService {
  private http = inject(HttpClient);
  private auth = inject(AuthService);
  readonly online = signal(navigator.onLine);
  readonly syncing = signal(false);
  private database?: Promise<IDBDatabase>;

  constructor() {
    window.addEventListener('online', () => { this.online.set(true); void this.synchronize(); });
    window.addEventListener('offline', () => this.online.set(false));
  }

  private scope(): string {
    const user = this.auth.currentUser();
    if (!user?.ci || !user.id_tenant) throw new Error('Ingrese con una cuenta de inmobiliaria.');
    return `${environment.apiUrl}|${user.id_tenant}|${user.ci}`;
  }

  private db(): Promise<IDBDatabase> {
    return this.database ??= new Promise((resolve, reject) => {
      const request = indexedDB.open('raices-offline-v1', 1);
      request.onupgradeneeded = () => {
        const store = request.result.createObjectStore('records', { keyPath: 'key' });
        store.createIndex('scope', 'scope');
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(new Error('No se pudo abrir el almacenamiento local.'));
    });
  }

  private async put(record: any) {
    const db = await this.db();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction('records', 'readwrite');
      tx.objectStore('records').put(record);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(new Error('No se pudo guardar. Revise el espacio del dispositivo.'));
      tx.onabort = () => reject(new Error('No se guardó la operación local.'));
    });
  }

  private async records(scope = this.scope()): Promise<any[]> {
    const db = await this.db();
    return new Promise((resolve, reject) => {
      const request = db.transaction('records').objectStore('records').index('scope').getAll(scope);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  private headers() {
    return new HttpHeaders({ Authorization: `Bearer ${localStorage.getItem('token')}` });
  }

  async snapshot(): Promise<any | undefined> {
    return (await this.records()).find(r => r.kind === 'snapshot')?.data;
  }

  async download() {
    const scope = this.scope();
    const data: any = await firstValueFrom(this.http.get(`${environment.apiUrl}/api/offline/catalogo`, { headers: this.headers() }));
    if (scope !== this.scope()) throw new Error('La sesión cambió. Descargue de nuevo.');
    await this.put({ key: `${scope}|snapshot`, scope, kind: 'snapshot', data });
    return data;
  }

  async operations(): Promise<LocalOperation[]> {
    return (await this.records()).filter(r => r.kind === 'operation').sort((a, b) => b.payload.registrado_en.localeCompare(a.payload.registrado_en));
  }

  async queue(prop: any, clientId: number, tipo: 'reserva' | 'venta_contado') {
    const scope = this.scope();
    const user = this.auth.currentUser();
    const snapshot = await this.snapshot();
    if (!snapshot?.clientes.some((c: any) => c.id_cliente === clientId)) throw new Error('Seleccione un cliente descargado.');
    if (!snapshot.propiedades.some((p: any) => p.id_propiedad === prop.id_propiedad) || prop.estado !== 'Disponible') throw new Error('Seleccione una propiedad disponible en el catálogo local.');
    if ((await this.operations()).some(o => o.payload.id_propiedad === prop.id_propiedad &&
      (['local', 'pendiente', 'enviando'].includes(o.estado) || (o.estado === 'confirmada' && o.payload.version === prop.version)))) {
      throw new Error('Ya existe una operación local para esta propiedad. Revise su estado.');
    }
    const uuid = crypto.randomUUID();
    await this.put({ key: `${scope}|${uuid}`, scope, kind: 'operation', estado: 'local', payload: {
      uuid, id_tenant: user.id_tenant, ci_usuario: user.ci, id_sucursal: prop.id_sucursal,
      id_propiedad: prop.id_propiedad, id_cliente: clientId, tipo, registrado_en: new Date().toISOString(),
      version: prop.version, precio: String(prop.precio), total: String(prop.precio), cantidad: 1, forma_pago: 'Efectivo'
    }});
  }

  async synchronize() {
    if (this.syncing() || !navigator.onLine || !this.auth.currentUser()?.id_tenant) return;
    this.syncing.set(true);
    try {
      const scope = this.scope();
      const pending = (await this.operations()).filter(o => ['local', 'pendiente', 'enviando'].includes(o.estado));
      for (const op of pending) {
        if (scope !== this.scope()) break;
        op.estado = 'enviando';
        await this.put(op);
        try {
          const result: any = await firstValueFrom(this.http.post(`${environment.apiUrl}/api/offline/sincronizar`, op.payload, { headers: this.headers() }).pipe(timeout(20000)));
          if (result.uuid !== op.payload.uuid || !['confirmada', 'rechazada', 'conflicto', 'cancelada'].includes(result.estado)) throw new Error('Respuesta del servidor no reconocida.');
          op.estado = result.estado;
          op.resultado = result;
          op.motivo = result.motivo || 'Confirmada por el servidor.';
        } catch (error: any) {
          op.estado = 'pendiente';
          op.motivo = typeof error.error?.detail === 'string' ? error.error.detail : 'Sin confirmación. Se conserva para reintentar.';
          await this.put(op);
          break;
        }
        await this.put(op);
      }
    } finally { this.syncing.set(false); }
  }

  async cancel(op: LocalOperation) {
    if (op.scope !== this.scope()) throw new Error('Operación de otra cuenta.');
    const result: any = await firstValueFrom(this.http.put(`${environment.apiUrl}/api/offline/reservas/${op.payload.uuid}/cancelar`, {}, { headers: this.headers() }));
    if (result.uuid !== op.payload.uuid || result.estado !== 'cancelada') throw new Error('Cancelación sin confirmación.');
    await this.put({ ...op, estado: 'cancelada', resultado: result, motivo: result.motivo });
  }
}
