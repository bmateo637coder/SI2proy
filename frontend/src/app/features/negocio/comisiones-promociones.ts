import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { API, authHeaders, errorTexto, tienePermiso } from '../../core/services/api';

const ESTILOS = `
  table { width:100%; border-collapse:collapse; font-size:0.9rem; }
  th, td { padding:0.55rem; text-align:left; border-bottom:1px solid var(--border-light); }
  th { color:var(--text-muted); font-size:0.75rem; text-transform:uppercase; }
  .chip { font-size:0.7rem; padding:2px 8px; border-radius:10px; background:#e2e8f0; }
  .ok { background:#dcfce7; color:#166534; }
`;

/** CU-29: comisiones de agentes generadas por cada contrato y su liquidación. */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-comisiones',
  styles: [ESTILOS],
  template: `
<div class="animate-fade-in" style="padding:2rem;">
  <h2 style="color:var(--secondary-color);">Comisiones</h2>
  <p role="status" *ngIf="mensaje" style="font-weight:600;">{{ mensaje }}</p>
  <div style="display:flex;gap:1rem;margin-bottom:1rem;flex-wrap:wrap;">
    <div class="luxury-card" style="padding:1rem 1.5rem;"><small>PENDIENTE</small><br><b style="font-size:1.4rem;">{{ +(d?.pendiente || 0) | number:'1.2-2' }}</b></div>
    <div class="luxury-card" style="padding:1rem 1.5rem;"><small>LIQUIDADO</small><br><b style="font-size:1.4rem;">{{ +(d?.liquidado || 0) | number:'1.2-2' }}</b></div>
    <select class="modern-input" style="width:auto;align-self:center;" [(ngModel)]="filtro" (change)="cargar()">
      <option value="">Todas</option><option>Pendiente</option><option>Liquidada</option></select>
  </div>
  <div class="luxury-card" style="overflow-x:auto;">
    <table>
      <thead><tr><th>Contrato</th><th>Inmueble</th><th>Agente</th><th>Base</th><th>%</th><th>Comisión</th><th>Estado</th><th></th></tr></thead>
      <tbody>
        <tr *ngFor="let c of d?.comisiones">
          <td>#{{ c.id_contrato }} {{ c.tipo }}<br><small style="color:var(--text-muted);">{{ c.nota }}</small></td><td>{{ c.propiedad }}</td><td>{{ c.agente }}</td>
          <td>{{ +c.base | number:'1.2-2' }}</td><td>{{ +c.porcentaje }}%</td><td><b>{{ +c.monto | number:'1.2-2' }}</b></td>
          <td><span class="chip" [class.ok]="c.estado === 'Liquidada'">{{ c.estado }}</span></td>
          <td><button *ngIf="admin && c.estado === 'Pendiente'" class="btn-secondary" (click)="liquidar(c)">Liquidar</button></td>
        </tr>
        <tr *ngIf="!d?.comisiones?.length"><td colspan="8" style="color:var(--text-muted);">Sin comisiones. Se generan al crear o renovar contratos.</td></tr>
      </tbody>
    </table>
  </div>
</div>`,
})
export class Comisiones implements OnInit {
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  admin = tienePermiso('UI:MENU_USUARIOS');
  d: any = null;
  filtro = '';
  mensaje = '';

  ngOnInit() { this.cargar(); }

  cargar() {
    const params: any = this.filtro ? { estado: this.filtro } : {};
    this.http.get<any>(API + '/api/comisiones', { headers: authHeaders(), params }).subscribe(d => { this.d = d; this.cdr.detectChanges(); });
  }

  liquidar(c: any) {
    if (!confirm(`¿Liquidar ${c.monto} a ${c.agente}?`)) return;
    this.http.post(`${API}/api/comisiones/${c.id}/liquidar`, {}, { headers: authHeaders() }).subscribe({
      next: () => { this.mensaje = 'Comisión liquidada; se notificó al agente.'; this.cargar(); },
      error: e => { this.mensaje = errorTexto(e, 'No se pudo liquidar.'); this.cdr.detectChanges(); },
    });
  }
}

/** CU-25: promociones temporales con descuento, visibles en el catálogo. */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-promociones',
  styles: [ESTILOS],
  template: `
<div class="animate-fade-in" style="padding:2rem;">
  <h2 style="color:var(--secondary-color);">Promociones</h2>
  <p role="status" *ngIf="mensaje" style="font-weight:600;">{{ mensaje }}</p>
  <form class="luxury-card" (ngSubmit)="crear()" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:0.75rem;margin-bottom:1rem;">
    <select class="modern-input" name="p" [(ngModel)]="nueva.id_propiedad"><option [ngValue]="null">Inmueble…</option>
      <option *ngFor="let p of propiedades" [ngValue]="p.id_propiedad">{{ p.titulo }}</option></select>
    <input class="modern-input" name="t" [(ngModel)]="nueva.titulo" placeholder="Título (ej. Oferta de lanzamiento)">
    <label>Descuento %<input class="modern-input" type="number" name="d" [(ngModel)]="nueva.descuento_pct" min="1" max="90"></label>
    <label>Desde<input class="modern-input" type="date" name="i" [(ngModel)]="nueva.inicio"></label>
    <label>Hasta<input class="modern-input" type="date" name="f" [(ngModel)]="nueva.fin"></label>
    <button class="btn-primary" [disabled]="!nueva.id_propiedad || !nueva.titulo || !nueva.descuento_pct">Crear promoción</button>
  </form>
  <div class="luxury-card" style="overflow-x:auto;">
    <table>
      <thead><tr><th>Inmueble</th><th>Promoción</th><th>Precio</th><th>Precio promo</th><th>Vigencia</th><th>Estado</th><th></th></tr></thead>
      <tbody>
        <tr *ngFor="let p of promociones">
          <td>{{ p.propiedad }}</td><td>{{ p.titulo }} (-{{ +p.descuento_pct }}%)</td><td>{{ +p.precio | number:'1.0-0' }}</td>
          <td><b>{{ +p.precio_promocional | number:'1.0-0' }}</b></td><td>{{ p.inicio }} → {{ p.fin }}</td>
          <td><span class="chip" [class.ok]="p.vigente">{{ p.vigente ? 'Vigente' : (p.activa ? 'Fuera de fecha' : 'Pausada') }}</span></td>
          <td style="white-space:nowrap;">
            <button class="btn-secondary" (click)="activar(p)">{{ p.activa ? 'Pausar' : 'Activar' }}</button>
            <button class="btn-secondary" style="color:#dc2626;" (click)="borrar(p)">Eliminar</button>
          </td>
        </tr>
        <tr *ngIf="!promociones.length"><td colspan="7" style="color:var(--text-muted);">No hay promociones.</td></tr>
      </tbody>
    </table>
  </div>
</div>`,
})
export class Promociones implements OnInit {
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  promociones: any[] = [];
  propiedades: any[] = [];
  mensaje = '';
  nueva: any = { id_propiedad: null, titulo: '', descuento_pct: 10, inicio: new Date().toISOString().slice(0, 10),
                 fin: new Date(Date.now() + 30 * 864e5).toISOString().slice(0, 10) };

  ngOnInit() {
    this.cargar();
    this.http.get<any[]>(API + '/modulo_inmuebles/propiedades', { headers: authHeaders() }).subscribe(p => { this.propiedades = p.filter(x => x.estado === 'Disponible'); this.cdr.detectChanges(); });
  }

  cargar() { this.http.get<any[]>(API + '/api/promociones', { headers: authHeaders() }).subscribe(p => { this.promociones = p; this.cdr.detectChanges(); }); }

  crear() {
    this.http.post(API + '/api/promociones', this.nueva, { headers: authHeaders() }).subscribe({
      next: () => { this.mensaje = 'Promoción creada: ya se muestra en el catálogo.'; this.nueva.titulo = ''; this.nueva.id_propiedad = null; this.cargar(); },
      error: e => { this.mensaje = errorTexto(e, 'No se pudo crear la promoción.'); this.cdr.detectChanges(); },
    });
  }

  activar(p: any) { this.http.put(`${API}/api/promociones/${p.id}`, { activa: !p.activa }, { headers: authHeaders() }).subscribe(() => this.cargar()); }

  borrar(p: any) {
    if (confirm('¿Eliminar la promoción?')) this.http.delete(`${API}/api/promociones/${p.id}`, { headers: authHeaders() }).subscribe(() => this.cargar());
  }
}
