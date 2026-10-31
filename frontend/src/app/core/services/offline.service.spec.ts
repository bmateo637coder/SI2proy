import 'fake-indexeddb/auto';
import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { OfflineService } from './offline.service';
import { AuthService } from './auth.service';

describe('Persistencia y sincronización offline', () => {
  let service: OfflineService;
  let http: HttpTestingController;
  const user = signal<any>(null);
  const prop = { id_propiedad: 1, id_sucursal: 1, titulo: 'Casa', precio: '1000.00', estado: 'Disponible', tipo_operacion: 'Venta', version: 1 };
  beforeEach(() => {
    user.set({ ci: crypto.randomUUID(), id_tenant: 1 });
    localStorage.setItem('token', 'test');
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting(), { provide: AuthService, useValue: { currentUser: user, tenantId: () => user()?.id_tenant } }] });
    service = TestBed.inject(OfflineService); http = TestBed.inject(HttpTestingController);
  });
  afterEach(() => http.verify());
  async function download() {
    const task = service.download();
    http.expectOne(r => r.url.endsWith('/api/offline/catalogo')).flush({ id_tenant: 1, ci_usuario: user().ci, descargado_en: new Date().toISOString(),
      propiedades: [prop], clientes: [{ id_cliente: 1, nombre: 'Cliente' }], sucursales: [{ id_sucursal: 1, nombre: 'Matriz' }] });
    await task;
  }
  it('recupera catálogo y operación desde otra instancia y separa cuentas', async () => {
    await download(); await service.queue(prop, 1, 'reserva');
    const reopened = TestBed.runInInjectionContext(() => new OfflineService());
    expect((await reopened.snapshot()).propiedades[0].titulo).toBe('Casa');
    expect((await reopened.operations())[0].estado).toBe('local');
    user.set({ ci: 'otra-cuenta', id_tenant: 2 });
    expect(await reopened.operations()).toEqual([]);
    expect(await reopened.snapshot()).toBeUndefined();
  });
  it('conserva UUID y datos tras un fallo y confirma un reintento', async () => {
    await download(); await service.queue(prop, 1, 'venta_contado');
    const original = (await service.operations())[0].payload;
    const failed = service.synchronize();
    await vi.waitFor(() => http.expectOne(r => r.url.endsWith('/sincronizar')).flush({}, { status: 503, statusText: 'Unavailable' }));
    await failed;
    expect((await service.operations())[0].estado).toBe('pendiente');
    const retry = service.synchronize();
    await vi.waitFor(() => {
      const request = http.expectOne(r => r.url.endsWith('/sincronizar'));
      expect(request.request.body).toEqual(original);
      request.flush({ uuid: original.uuid, estado: 'confirmada' });
    });
    await retry;
    const saved = (await service.operations())[0];
    expect(saved.estado).toBe('confirmada'); expect(saved.payload).toEqual(original);
  });
  it('conserva conflictos en el historial', async () => {
    await download(); await service.queue(prop, 1, 'reserva');
    const op = (await service.operations())[0];
    const sending = service.synchronize();
    await vi.waitFor(() => http.expectOne(r => r.url.endsWith('/sincronizar')).flush({ uuid: op.payload.uuid, estado: 'conflicto', motivo: 'Propiedad vendida.' }));
    await sending;
    expect((await service.operations())[0].motivo).toBe('Propiedad vendida.');
    await service.synchronize(); // No reenvía conflictos como si fueran nuevas operaciones.
  });
});
