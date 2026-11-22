import { Component, OnInit, OnDestroy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Subscription } from 'rxjs';
import { API, authHeaders, errorTexto } from '../../core/services/api';

/** CU-33: dashboard gerencial con KPIs de cartera, ingresos por cuotas, comisiones y rendimiento comercial. */
@Component({
  standalone: true,
  imports: [CommonModule],
  selector: 'app-dashboard-gerencial',
  styles: [`
    .dashboard-page {padding:2rem;min-width:0;} .grid2 > *, .kpis > * {min-width:0;}
    @media(max-width:700px) {.dashboard-page {padding:1rem;} .kpis {grid-template-columns:minmax(0,1fr);} }
    .kpis { display:grid; grid-template-columns:repeat(auto-fill,minmax(190px,1fr)); gap:1rem; margin-bottom:1.5rem; }
    .kpi { background:white; border:1px solid var(--border-light); border-radius:12px; padding:1rem 1.25rem; }
    .kpi small { display:block; color:var(--text-muted); text-transform:uppercase; font-size:0.7rem; letter-spacing:1px; }
    .kpi b { font-size:1.6rem; color:var(--secondary-color); }
    .kpi span { font-size:0.8rem; color:var(--text-muted); }
    .grid2 { display:grid; grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr)); gap:1.5rem; margin-bottom:1.5rem; }
    .barras { display:flex; align-items:flex-end; gap:6px; height:180px; padding-top:1rem; }
    .barra { flex:1; display:flex; flex-direction:column; align-items:center; justify-content:flex-end; height:100%; }
    .barra div { width:100%; background:linear-gradient(180deg,#a855f7,#7e22ce); border-radius:4px 4px 0 0; min-height:2px; }
    .barra small { font-size:0.65rem; color:var(--text-muted); margin-top:4px; }
    table { width:100%; border-collapse:collapse; font-size:0.9rem; }
    th, td { padding:0.6rem; text-align:left; border-bottom:1px solid var(--border-light); }
    th { color:var(--text-muted); font-size:0.75rem; text-transform:uppercase; }
    .fila { display:flex; justify-content:space-between; padding:0.35rem 0; border-bottom:1px dashed var(--border-light); }
  `],
  template: `
<div class="animate-fade-in dashboard-page">
  <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:.5rem;">
    <h2 style="color:var(--secondary-color);">Dashboard gerencial</h2>
    <button class="btn-secondary" (click)="cargar()" [disabled]="loading">Actualizar</button>
  </div>
  <p *ngIf="loading" role="status">Cargando dashboard…</p>
  <p *ngIf="error" role="alert" style="color:#dc2626;font-weight:600;">{{ error }}</p>
  <ng-container *ngIf="d">
    <div class="kpis">
      <div class="kpi"><small>Ocupación de cartera</small><b>{{ d.cartera.ocupacion_pct }}%</b><br><span>{{ d.cartera.total }} inmuebles</span></div>
      <div class="kpi"><small>Ingresos cobrados</small><b>{{ +d.ingresos.cobrado_total | number:'1.0-0' }}</b><br><span>{{ d.ingresos.contratos }} contratos</span></div>
      <div class="kpi"><small>Por cobrar</small><b>{{ +d.ingresos.por_cobrar | number:'1.0-0' }}</b><br><span>Vencido {{ +d.ingresos.vencido | number:'1.0-0' }}</span></div>
      <div class="kpi"><small>Morosidad</small><b [style.color]="d.ingresos.morosidad_pct > 10 ? '#dc2626' : ''">{{ d.ingresos.morosidad_pct }}%</b><br><span>{{ d.ingresos.cuotas_vencidas }} cuotas vencidas</span></div>
      <div class="kpi"><small>Comisiones generadas</small><b>{{ +d.comisiones.generadas | number:'1.0-0' }}</b><br><span>Cobradas {{ +d.comisiones.cobradas | number:'1.0-0' }}</span></div>
      <div class="kpi"><small>Visitas próximas 7 días</small><b>{{ d.visitas.proximas_7_dias }}</b></div>
      <div class="kpi"><small>Mantenimiento abierto</small><b>{{ d.mantenimiento.abiertas }}</b><br><span [style.color]="d.mantenimiento.criticas_abiertas ? '#dc2626' : ''">{{ d.mantenimiento.criticas_abiertas }} críticas · costo {{ +d.mantenimiento.costo_total | number:'1.0-0' }}</span></div>
    </div>

    <div class="grid2">
      <div class="luxury-card">
        <h3 style="margin-top:0;">Ingresos cobrados por mes</h3>
        <div class="barras">
          <div class="barra" *ngFor="let m of d.ingresos.por_mes" [title]="m.mes + ': ' + m.monto">
            <div [style.height.%]="altura(m.monto)"></div><small>{{ m.mes.slice(5) }}</small>
          </div>
        </div>
      </div>
      <div class="luxury-card">
        <h3 style="margin-top:0;">Cartera</h3>
        <div class="fila" *ngFor="let e of entradas(d.cartera.por_estado)"><span>{{ e[0] }}</span><b>{{ e[1] }}</b></div>
        <h4>Por operación</h4>
        <div class="fila" *ngFor="let e of entradas(d.cartera.por_operacion)"><span>{{ e[0] }}</span><b>{{ e[1] }}</b></div>
        <p style="font-size:0.75rem;color:var(--text-muted);">Comisión: Venta {{ d.comisiones.porcentajes.Venta }}% · Alquiler {{ d.comisiones.porcentajes.Alquiler }}% · Anticrético {{ d.comisiones.porcentajes.Anticretico }}% (configurable).</p>
      </div>
    </div>

    <div class="luxury-card" style="overflow-x:auto;">
      <h3 style="margin-top:0;">Rendimiento comercial por agente</h3>
      <table>
        <thead><tr><th>Agente</th><th>Inmuebles</th><th>Visitas (realizadas)</th><th>Contratos</th><th>Monto cerrado</th><th>Comisión generada</th><th>Comisión cobrada</th><th>Conv. visita→contrato</th></tr></thead>
        <tbody>
          <tr *ngFor="let a of d.rendimiento_agentes">
            <td>{{ a.agente }}<small style="display:block">{{ a.inmobiliaria }}</small></td><td>{{ a.inmuebles }}</td><td>{{ a.visitas }} ({{ a.visitas_realizadas }})</td><td>{{ a.contratos }}</td>
            <td>{{ +a.monto_cerrado | number:'1.0-0' }}</td><td>{{ +a.comision_generada | number:'1.0-0' }}</td><td>{{ +a.comision_cobrada | number:'1.0-0' }}</td>
            <td>{{ a.conversion_visitas === null ? '—' : a.conversion_visitas + '%' }}</td>
          </tr>
          <tr *ngIf="!d.rendimiento_agentes.length"><td colspan="8" style="color:var(--text-muted);">Sin agentes registrados.</td></tr>
        </tbody>
      </table>
    </div>
  </ng-container>
</div>`,
})
export class DashboardGerencial implements OnInit, OnDestroy {
  loading = false;
  private request?: Subscription;
  ngOnDestroy() { this.request?.unsubscribe(); }
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  d: any = null;
  error = '';
  private maxMes = 0;

  ngOnInit() { this.cargar(); }

  cargar() {
    this.request?.unsubscribe();
    this.loading = true;
    this.request = this.http.get<any>(API + '/api/gerencia/dashboard', { headers: authHeaders() }).subscribe({
      next: d => { this.loading = false; this.d = d; this.maxMes = Math.max(0, ...d.ingresos.por_mes.map((m: any) => +m.monto)); this.error = ''; this.cdr.detectChanges(); },
      error: e => { this.loading = false; this.d = null; this.error = errorTexto(e, 'No se pudo cargar el dashboard.'); this.cdr.detectChanges(); },
    });
  }

  altura(monto: any) { return this.maxMes ? Math.max(1, (100 * +monto) / this.maxMes) : 1; }

  entradas(o: any): [string, number][] { return Object.entries(o || {}) as [string, number][]; }
}