import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { Bitacora } from './bitacora';

describe('Bitácora segura', () => {
  let fixture: ComponentFixture<Bitacora>;
  let http: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Bitacora], providers: [provideHttpClient(), provideHttpClientTesting()]
    }).compileComponents();
    fixture = TestBed.createComponent(Bitacora);
    http = TestBed.inject(HttpTestingController);
    fixture.autoDetectChanges();
    await fixture.whenStable();
  });
  afterEach(() => http.verify());

  it('conserva + y = y muestra los registros sin otro clic', async () => {
    fixture.componentInstance.devKey = ' clave+prueba= ';
    fixture.componentInstance.cargarBitacora();
    const req = http.expectOne(r => r.url.endsWith('/admin/bitacora'));
    expect(req.request.urlWithParams).toContain('clave%2Bprueba=');
    expect(req.request.params.get('dev_key')).toBe('clave+prueba=');
    req.flush([{ fecha_hora: '2026-11-01', usuario: 'saas', accion: 'Acción de prueba', ip: '127.0.0.1' }]);
    await fixture.whenStable();
    expect(fixture.nativeElement.textContent).toContain('Acción de prueba');
    expect(fixture.nativeElement.textContent).not.toContain('Cargando...');
    expect(fixture.nativeElement.querySelector('button').disabled).toBe(false);
  });

  it('admite la clave codificada y explica una bitácora vacía', async () => {
    fixture.componentInstance.devKey = 'clave%2Bprueba%3D';
    fixture.componentInstance.cargarBitacora();
    const req = http.expectOne(r => r.url.endsWith('/admin/bitacora'));
    expect(req.request.params.get('dev_key')).toBe('clave+prueba=');
    req.flush([]);
    await fixture.whenStable();
    expect(fixture.nativeElement.textContent).toContain('No hay registros');
    expect(fixture.nativeElement.querySelector('button').disabled).toBe(false);
  });

  it('muestra el error y permite reintentar sin otro clic', async () => {
    fixture.componentInstance.devKey = 'incorrecta';
    fixture.componentInstance.cargarBitacora();
    http.expectOne(r => r.url.endsWith('/admin/bitacora')).flush({}, { status: 403, statusText: 'Forbidden' });
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('[role="alert"]').textContent).toContain('Llave inválida');
    expect(fixture.nativeElement.querySelector('button').disabled).toBe(false);
  });

  it('limita la espera si el servidor no responde', async () => {
    vi.useFakeTimers();
    try {
      fixture.componentInstance.devKey = 'clave';
      fixture.componentInstance.cargarBitacora();
      const req = http.expectOne(r => r.url.endsWith('/admin/bitacora'));
      await vi.advanceTimersByTimeAsync(90001);
      expect(req.cancelled).toBe(true);
      expect(fixture.componentInstance.loading).toBe(false);
      expect(fixture.componentInstance.error).toContain('tardó demasiado');
    } finally {
      vi.useRealTimers();
    }
  });
});
