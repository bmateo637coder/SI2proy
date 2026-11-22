import { Component, AfterViewInit, OnDestroy, ChangeDetectorRef, ElementRef, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import * as L from 'leaflet';
import { Subscription } from 'rxjs';
import { API, authHeaders, errorTexto } from '../../core/services/api';

/** CU-35: mapa de calor de zonas. Cada zona se dibuja en el centro de sus inmuebles geolocalizados,
 *  con radio y color proporcionales a la métrica elegida (cierres, monto o precio por m²). */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-mapa-calor',
  styles: [`
    .map-page { padding:2rem; min-width:0; }
    .map-layout { display:grid;grid-template-columns:minmax(0,2fr) minmax(280px,1fr);gap:1.5rem;margin-top:1rem; }
    .map-layout > * { min-width:0; }
    .map-toolbar { display:flex;gap:.5rem;align-items:center;flex-wrap:wrap; }
    .mapa { height:clamp(300px,55vh,500px); border-radius:12px; border:1px solid var(--border-light); z-index:0; }
    .leyenda { display:flex; align-items:center; gap:0.5rem; font-size:0.8rem; color:var(--text-muted); margin-top:0.5rem; }
    .degradado { width:160px; height:10px; border-radius:5px; background:linear-gradient(90deg,#fde68a,#f97316,#b91c1c); }
    @media(max-width:900px) { .map-page { padding:1rem; } .map-layout { grid-template-columns:minmax(0,1fr); } }
    table { width:100%; border-collapse:collapse; font-size:0.9rem; }
    th, td { padding:0.55rem; text-align:left; border-bottom:1px solid var(--border-light); }
    th { color:var(--text-muted); font-size:0.75rem; text-transform:uppercase; }
  `],
  template: `
<div class="animate-fade-in map-page">
  <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:1rem;">
    <h2 style="color:var(--secondary-color);margin:0;">Mapa de calor de zonas</h2>
    <div class="map-toolbar">
      <select aria-label="Métrica del mapa" class="modern-input" [(ngModel)]="metrica" (change)="cargar()" style="width:auto;">
        <option value="cierres">Ventas cerradas</option>
        <option value="monto">Monto cerrado</option>
        <option value="precio_m2">Precio por m²</option>
      </select>
      <button class="btn-primary" (click)="cargar(true)" [disabled]="cargando">{{ cargandoIA ? 'Analizando…' : 'Análisis con IA' }}</button>
    </div>
  </div>
  <p *ngIf="cargando" role="status">Cargando análisis de zonas…</p>
  <p *ngIf="error" role="alert" style="color:#dc2626;font-weight:600;">{{ error }}</p>
  <div *ngIf="resumen" class="luxury-card" style="margin:1rem 0;background:#faf5ff;">
    <b>Análisis</b> <small style="color:var(--text-muted);">({{ modoResumen === 'gemini' ? 'Gemini' : 'resumen automático' }})</small>
    <p style="margin:0.4rem 0 0;">{{ resumen }}</p>
  </div>
  <div class="map-layout">
    <div>
      <button class="btn-secondary" (click)="encuadrar()" style="margin-bottom:.5rem;">Ver todas las zonas</button>
      <div #mapa class="mapa" aria-label="Mapa de zonas"></div>
      <div class="leyenda"><span>Menor</span><div class="degradado"></div><span>Mayor {{ etiqueta() }}</span></div>
      <p *ngIf="sinCoordenadas.length" style="font-size:0.8rem;color:var(--text-muted);">Sin coordenadas (no aparecen en el mapa): {{ sinCoordenadas.join(', ') }}. Cargue latitud/longitud en sus inmuebles.</p>
    </div>
    <div class="luxury-card" style="overflow-x:auto;">
      <h3 style="margin-top:0;">Ranking por {{ etiqueta() }}</h3>
      <table>
        <thead><tr><th>Zona</th><th>Inm.</th><th>Ventas</th><th>Monto</th><th>$/m²</th></tr></thead>
        <tbody>
          <tr *ngFor="let z of zonas" (click)="enfocar(z)" (keydown.enter)="enfocar(z)" [attr.tabindex]="ubicable(z) ? 0 : null" [attr.title]="ubicable(z) ? 'Centrar esta zona' : 'Sin coordenadas'" style="cursor:pointer;">
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
  cargando = false;
  private request?: Subscription;
  private resize?: ResizeObserver;

  ngAfterViewInit() {
    this.mapa = L.map(this.mapaRef.nativeElement).setView([-17.7833, -63.1821], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '&copy; OpenStreetMap',
    }).addTo(this.mapa);
    this.capa.addTo(this.mapa);
    this.resize = new ResizeObserver(() => this.mapa?.invalidateSize({pan:false}));
    this.resize.observe(this.mapaRef.nativeElement);
    this.cargar();
  }

  ngOnDestroy() { this.request?.unsubscribe(); this.resize?.disconnect(); this.mapa?.remove(); }

  etiqueta() { return ({ cierres: 'cierres', monto: 'monto cerrado', precio_m2: 'precio por m²' } as any)[this.metrica]; }

  /** Escala amarillo → naranja → rojo según la intensidad (0..1). */
  color(i: number) {
    const t = Math.max(0, Math.min(1, i || 0));
    const mezcla = (a: number[], b: number[], k: number) => a.map((v, j) => Math.round(v + (b[j] - v) * k));
    const [r, g, b] = t < 0.5 ? mezcla([253, 230, 138], [249, 115, 22], t * 2) : mezcla([249, 115, 22], [185, 28, 28], (t - 0.5) * 2);
    return `rgb(${r},${g},${b})`;
  }

  cargar(conIA = false) {
    this.request?.unsubscribe();
    this.cargando = true;
    this.cargandoIA = conIA;
    this.resumen = '';
    this.modoResumen = '';
    this.error = '';
    const params: any = { metrica: this.metrica, resumen_ia: conIA };
    this.request = this.http.get<any>(API + '/api/analitica/zonas', { headers: authHeaders(), params }).subscribe({
      next: r => {
        this.zonas = r.zonas || []; this.sinCoordenadas = r.sin_coordenadas || []; this.error = '';
        if (conIA) { this.resumen = r.resumen; this.modoResumen = r.modo_resumen; }
        this.cargando = false; this.cargandoIA = false;
        this.dibujar();
        this.cdr.detectChanges();
      },
      error: e => { this.cargando = false; this.cargandoIA = false; this.zonas = []; this.sinCoordenadas = []; this.capa.clearLayers(); this.error = errorTexto(e, 'No se pudo cargar el análisis de zonas.'); this.cdr.detectChanges(); },
    });
  }

  private dibujar() {
    if (!this.mapa) return;
    this.capa.clearLayers();
    const puntos: L.LatLngExpression[] = [];
    for (const z of this.zonas.filter(z => this.ubicable(z))) {
      const centro: L.LatLngExpression = [+z.latitud, +z.longitud];
      const intensity = Math.max(0, Math.min(1, Number(z.intensidad) || 0));
      puntos.push(centro);
      const c = this.color(z.intensidad);
      // Halo difuso + núcleo, para simular la densidad de un mapa de calor.
      L.circle(centro, { radius: 400 + 1600 * intensity, color: c, fillColor: c, fillOpacity: 0.25, weight: 0 }).addTo(this.capa);
      L.circleMarker(centro, { radius: 6 + 10 * intensity, color: '#ffffff', weight: 2, fillColor: c, fillOpacity: 0.95 })
        .bindPopup(() => {
          const el = document.createElement('div');
          el.textContent = `${z.zona} · ${z.inmobiliaria || ''}: ${z.cierres} ventas, monto ${Number(z.monto).toLocaleString()}`;
          return el;
        })
        .addTo(this.capa);
    }
    this.encuadrar();
  }

  ubicable(z: any) {
    return z.latitud != null && z.longitud != null && z.latitud !== '' && z.longitud !== '' &&
      Number.isFinite(+z.latitud) && Number.isFinite(+z.longitud) && Math.abs(+z.latitud) <= 85.05112878 && Math.abs(+z.longitud) <= 180;
  }

  encuadrar() {
    const points = this.zonas.filter(z => this.ubicable(z)).map(z => L.latLng(+z.latitud, +z.longitud));
    if (points.length && this.mapa) {
      this.mapa.invalidateSize({pan:false});
      this.mapa.fitBounds(L.latLngBounds(points).pad(.3), {maxZoom:14});
    }
  }

  enfocar(z: any) {
    if (this.mapa && this.ubicable(z)) this.mapa.setView([z.latitud, z.longitud], 14);
  }
}
