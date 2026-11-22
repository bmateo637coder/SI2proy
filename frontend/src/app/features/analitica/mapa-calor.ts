import { Component, AfterViewInit, OnDestroy, ChangeDetectorRef, ElementRef, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import * as L from 'leaflet';
import { API, authHeaders, errorTexto } from '../../core/services/api';

/** CU-35: mapa de calor de zonas. Cada zona se dibuja en el centro de sus inmuebles geolocalizados,
 *  con radio y color proporcionales a la métrica elegida (cierres, monto o precio por m²). */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-mapa-calor',
  styles: [`
    .mapa { height:480px; border-radius:12px; border:1px solid var(--border-light); z-index:0; }
    .leyenda { display:flex; align-items:center; gap:0.5rem; font-size:0.8rem; color:var(--text-muted); margin-top:0.5rem; }
    .degradado { width:160px; height:10px; border-radius:5px; background:linear-gradient(90deg,#fde68a,#f97316,#b91c1c); }
    table { width:100%; border-collapse:collapse; font-size:0.9rem; }
    th, td { padding:0.55rem; text-align:left; border-bottom:1px solid var(--border-light); }
    th { color:var(--text-muted); font-size:0.75rem; text-transform:uppercase; }
  `],
  template: `
<div class="animate-fade-in" style="padding:2rem;">
  <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:1rem;">
    <h2 style="color:var(--secondary-color);margin:0;">Mapa de calor de zonas</h2>
    <div style="display:flex;gap:0.5rem;align-items:center;">
      <select class="modern-input" [(ngModel)]="metrica" (change)="cargar()" style="width:auto;">
        <option value="cierres">Ventas cerradas</option>
        <option value="monto">Monto cerrado</option>
        <option value="precio_m2">Precio por m²</option>
      </select>
      <button class="btn-primary" (click)="cargar(true)" [disabled]="cargandoIA">{{ cargandoIA ? 'Analizando…' : 'Análisis con IA' }}</button>
    </div>
  </div>
  <p *ngIf="error" style="color:#dc2626;font-weight:600;">{{ error }}</p>
  <div *ngIf="resumen" class="luxury-card" style="margin:1rem 0;background:#faf5ff;">
    <b>Análisis</b> <small style="color:var(--text-muted);">({{ modoResumen === 'gemini' ? 'Gemini' : 'resumen automático' }})</small>
    <p style="margin:0.4rem 0 0;">{{ resumen }}</p>
  </div>
  <div style="display:grid;grid-template-columns:minmax(0,2fr) minmax(280px,1fr);gap:1.5rem;margin-top:1rem;">
    <div>
      <div #mapa class="mapa"></div>
      <div class="leyenda"><span>Menor</span><div class="degradado"></div><span>Mayor {{ etiqueta() }}</span></div>
      <p *ngIf="sinCoordenadas.length" style="font-size:0.8rem;color:var(--text-muted);">Sin coordenadas (no aparecen en el mapa): {{ sinCoordenadas.join(', ') }}. Cargue latitud/longitud en sus inmuebles.</p>
    </div>
    <div class="luxury-card" style="overflow-x:auto;">
      <h3 style="margin-top:0;">Ranking por {{ etiqueta() }}</h3>
      <table>
        <thead><tr><th>Zona</th><th>Inm.</th><th>Ventas</th><th>Monto</th><th>$/m²</th></tr></thead>
        <tbody>
          <tr *ngFor="let z of zonas" (click)="enfocar(z)" style="cursor:pointer;">
            <td><span [style.background]="color(z.intensidad)" style="display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:6px;"></span>{{ z.zona }}<small style="display:block">{{ z.inmobiliaria }}</small></td>
            <td>{{ z.inmuebles }}</td><td>{{ z.cierres }}</td><td>{{ +z.monto | number:'1.0-0' }}</td><td>{{ z.precio_m2 === null ? '—' : (z.precio_m2 | number:'1.0-0') }}</td>
          </tr>
          <tr *ngIf="!zonas.length"><td colspan="5" style="color:var(--text-muted);">Sin datos.</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>`,
})
export class MapaCalor implements AfterViewInit, OnDestroy {
  @ViewChild('mapa') mapaRef!: ElementRef<HTMLDivElement>;
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  private mapa?: L.Map;
  private capa = L.layerGroup();
  metrica: 'cierres' | 'monto' | 'precio_m2' = 'cierres';
  zonas: any[] = [];
  sinCoordenadas: string[] = [];
  resumen = '';
  modoResumen = '';
  error = '';
  cargandoIA = false;

  ngAfterViewInit() {
    this.mapa = L.map(this.mapaRef.nativeElement).setView([-17.7833, -63.1821], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '&copy; OpenStreetMap',
    }).addTo(this.mapa);
    this.capa.addTo(this.mapa);
    this.cargar();
  }

  ngOnDestroy() { this.mapa?.remove(); }

  etiqueta() { return ({ cierres: 'cierres', monto: 'monto cerrado', precio_m2: 'precio por m²' } as any)[this.metrica]; }

  /** Escala amarillo → naranja → rojo según la intensidad (0..1). */
  color(i: number) {
    const t = Math.max(0, Math.min(1, i || 0));
    const mezcla = (a: number[], b: number[], k: number) => a.map((v, j) => Math.round(v + (b[j] - v) * k));
    const [r, g, b] = t < 0.5 ? mezcla([253, 230, 138], [249, 115, 22], t * 2) : mezcla([249, 115, 22], [185, 28, 28], (t - 0.5) * 2);
    return `rgb(${r},${g},${b})`;
  }

  cargar(conIA = false) {
    this.cargandoIA = conIA;
    const params: any = { metrica: this.metrica, resumen_ia: conIA };
    this.http.get<any>(API + '/api/analitica/zonas', { headers: authHeaders(), params }).subscribe({
      next: r => {
        this.zonas = r.zonas; this.sinCoordenadas = r.sin_coordenadas; this.error = '';
        if (conIA) { this.resumen = r.resumen; this.modoResumen = r.modo_resumen; }
        this.cargandoIA = false;
        this.dibujar();
        this.cdr.detectChanges();
      },
      error: e => { this.cargandoIA = false; this.error = errorTexto(e, 'No se pudo cargar el análisis de zonas.'); this.cdr.detectChanges(); },
    });
  }

  private dibujar() {
    if (!this.mapa) return;
    this.capa.clearLayers();
    const puntos: L.LatLngExpression[] = [];
    for (const z of this.zonas.filter(z => z.latitud !== null)) {
      const centro: L.LatLngExpression = [z.latitud, z.longitud];
      puntos.push(centro);
      const c = this.color(z.intensidad);
      // Halo difuso + núcleo, para simular la densidad de un mapa de calor.
      L.circle(centro, { radius: 400 + 1600 * z.intensidad, color: c, fillColor: c, fillOpacity: 0.25, weight: 0 }).addTo(this.capa);
      L.circleMarker(centro, { radius: 6 + 10 * z.intensidad, color: '#ffffff', weight: 2, fillColor: c, fillOpacity: 0.95 })
        .bindPopup(() => {
          const el = document.createElement('div');
          el.textContent = `${z.zona} ? ${z.inmobiliaria || ''}: ${z.cierres} ventas, monto ${Number(z.monto).toLocaleString()}`;
          return el;
        })
        .addTo(this.capa);
    }
    if (puntos.length) this.mapa.fitBounds(L.latLngBounds(puntos).pad(0.3), { maxZoom: 14 });
  }

  enfocar(z: any) {
    if (this.mapa && z.latitud !== null) this.mapa.setView([z.latitud, z.longitud], 14);
  }
}
