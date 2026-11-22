import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { API, authHeaders, errorTexto } from '../../core/services/api';

/** CU-30: inmuebles favoritos y alertas de búsqueda (avisos in-app y push FCM). */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-favoritos',
  template: `
<div class="animate-fade-in" style="padding:2rem;max-width:1100px;margin:0 auto;">
  <h2 style="color:var(--secondary-color);">Favoritos y alertas</h2>
  <p role="status" *ngIf="mensaje" style="font-weight:600;">{{ mensaje }}</p>

  <section class="luxury-card" style="margin-bottom:2rem;">
    <h3 style="margin-top:0;">Mis favoritos ({{ favoritos.length }})</h3>
    <p *ngIf="!favoritos.length" style="color:var(--text-muted);">Aún no guardó inmuebles. Use el corazón en el catálogo.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:1rem;">
      <div *ngFor="let f of favoritos" style="border:1px solid var(--border-light);border-radius:12px;overflow:hidden;">
        <img *ngIf="f.propiedad.imagenes?.length" [src]="imageUrl(f.propiedad.imagenes[0].url)" alt="" style="width:100%;height:130px;object-fit:cover;">
        <div style="padding:0.9rem;">
          <strong style="color:var(--secondary-color);">{{ f.propiedad.titulo }}</strong>
          <div style="font-size:0.85rem;color:var(--text-muted);">{{ f.propiedad.direccion }}</div>
          <div style="margin:0.4rem 0;"><b style="color:var(--primary-color);">{{ f.propiedad.precio | number:'1.0-0' }}</b> · {{ f.propiedad.tipo_operacion }}</div>
          <span *ngIf="!f.disponible" style="font-size:0.75rem;background:#fee2e2;color:#991b1b;padding:2px 8px;border-radius:10px;">Ya no disponible ({{ f.propiedad.estado }})</span>
          <div><button class="btn-secondary" style="margin-top:0.5rem;font-size:0.8rem;" (click)="quitar(f)">Quitar</button></div>
        </div>
      </div>
    </div>
  </section>

  <section class="luxury-card">
    <h3 style="margin-top:0;">Alertas de búsqueda</h3>
    <p style="color:var(--text-muted);font-size:0.9rem;">Cuando se publique un inmueble que cumpla los criterios recibirá una notificación en la aplicación y en su móvil (si activó las notificaciones push).</p>
    <form (ngSubmit)="crear()" style="display:grid;grid-template-columns:1fr 1fr;gap:0.75rem;margin-bottom:1.5rem;">
      <input class="modern-input" name="nombre" [(ngModel)]="nueva.nombre" placeholder="Nombre de la alerta (ej. Depto para estudiar)" required maxlength="100">
      <select class="modern-input" name="modo" [(ngModel)]="modo">
        <option value="texto">Describirla en lenguaje natural (IA)</option>
        <option value="filtros">Elegir filtros</option>
      </select>
      <input *ngIf="modo === 'texto'" class="modern-input" name="texto" [(ngModel)]="nueva.texto" style="grid-column:span 2;"
             placeholder="Ej. departamento en alquiler con 2 habitaciones hasta 4000 en Equipetrol">
      <ng-container *ngIf="modo === 'filtros'">
        <select class="modern-input" name="op" [(ngModel)]="filtros.tipo_operacion">
          <option [ngValue]="null">Cualquier operación</option><option>Venta</option><option>Alquiler</option><option value="Anticretico">Anticrético</option>
        </select>
        <input class="modern-input" type="number" name="pmax" [(ngModel)]="filtros.precio_max" placeholder="Precio máximo">
        <input class="modern-input" type="number" name="cuartos" [(ngModel)]="filtros.cuartos" placeholder="Habitaciones mínimas">
        <input class="modern-input" name="zona" [(ngModel)]="filtros.zona" placeholder="Zona (opcional)">
      </ng-container>
      <div style="grid-column:span 2;"><button class="btn-primary" [disabled]="ocupado || !nueva.nombre">Crear alerta</button></div>
    </form>
    <p *ngIf="!alertas.length" style="color:var(--text-muted);">No tiene alertas.</p>
    <div *ngFor="let a of alertas" style="display:flex;align-items:center;gap:1rem;border-top:1px solid var(--border-light);padding:0.75rem 0;">
      <div style="flex:1;">
        <strong>{{ a.nombre }}</strong>
        <div style="font-size:0.85rem;color:var(--text-muted);">{{ a.resumen }}</div>
      </div>
      <label style="font-size:0.85rem;"><input type="checkbox" [checked]="a.activa" (change)="activar(a, $any($event.target).checked)"> Activa</label>
      <button class="btn-secondary" style="color:#dc2626;" (click)="borrar(a)">Eliminar</button>
    </div>
  </section>
</div>`,
})
export class Favoritos implements OnInit {
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  api = API;
  imageUrl(url: string) { return /^(https?:|data:)/.test(url) ? url : API + url; }
  favoritos: any[] = [];
  alertas: any[] = [];
  mensaje = '';
  ocupado = false;
  modo: 'texto' | 'filtros' = 'texto';
  nueva: any = { nombre: '', texto: '' };
  filtros: any = { tipo_operacion: null, precio_max: null, cuartos: null, zona: '' };

  ngOnInit() { this.cargar(); }

  cargar() {
    this.http.get<any[]>(API + '/api/favoritos', { headers: authHeaders() }).subscribe(f => { this.favoritos = f; this.cdr.detectChanges(); });
    this.http.get<any[]>(API + '/api/alertas', { headers: authHeaders() }).subscribe(a => { this.alertas = a; this.cdr.detectChanges(); });
  }

  private avisar(m: string) { this.mensaje = m; this.ocupado = false; this.cdr.detectChanges(); }

  quitar(f: any) {
    this.http.delete(`${API}/api/favoritos/${f.id_propiedad}`, { headers: authHeaders() }).subscribe(() => this.cargar());
  }

  crear() {
    const body: any = { nombre: this.nueva.nombre };
    if (this.modo === 'texto') {
      body.texto = this.nueva.texto;
    } else {
      const c: any = {};
      for (const [k, v] of Object.entries(this.filtros)) if (v !== null && v !== '') c[k] = v;
      body.criterios = c;
    }
    this.ocupado = true;
    this.http.post<any>(API + '/api/alertas', body, { headers: authHeaders() }).subscribe({
      next: a => {
        this.avisar(`Alerta creada (${a.resumen}). Hoy ya hay ${a.coincidencias_actuales} inmueble(s) compatibles.`);
        this.nueva = { nombre: '', texto: '' };
        this.cargar();
      },
      error: e => this.avisar(errorTexto(e, 'No se pudo crear la alerta.')),
    });
  }

  activar(a: any, activa: boolean) {
    this.http.put(`${API}/api/alertas/${a.id}`, { activa }, { headers: authHeaders() }).subscribe(() => this.cargar());
  }

  borrar(a: any) {
    if (!confirm('¿Eliminar la alerta "' + a.nombre + '"?')) return;
    this.http.delete(`${API}/api/alertas/${a.id}`, { headers: authHeaders() }).subscribe(() => this.cargar());
  }
}
