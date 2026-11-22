import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { API, authHeaders, errorTexto, tienePermiso } from '../../core/services/api';

/** CU-34 solicitudes de mantenimiento + CU-37 workflow (la IA clasifica y el sistema asigna y notifica). */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-mantenimiento',
  styles: [`
    table { width:100%; border-collapse:collapse; font-size:0.9rem; }
    th, td { padding:0.6rem; text-align:left; border-bottom:1px solid var(--border-light); vertical-align:top; }
    th { color:var(--text-muted); font-size:0.75rem; text-transform:uppercase; }
    .urg { font-size:0.7rem; padding:2px 8px; border-radius:10px; background:#e2e8f0; }
    .Critica { background:#7f1d1d; color:white; } .Alta { background:#fee2e2; color:#991b1b; } .Baja { background:#dcfce7; color:#166534; }
    .panel { position:fixed; top:0; right:0; width:min(480px,100%); height:100%; background:white; box-shadow:-8px 0 30px rgba(0,0,0,0.15); z-index:1000; padding:1.5rem; overflow-y:auto; }
    .tabs button { margin-right:0.5rem; }
  `],
  template: `
<div class="animate-fade-in" style="padding:2rem;">
  <h2 style="color:var(--secondary-color);">Mantenimiento e incidencias</h2>
  <p role="status" *ngIf="mensaje" style="font-weight:600;">{{ mensaje }}</p>
  <div class="tabs" style="margin-bottom:1rem;">
    <button [class]="tab === 'lista' ? 'btn-primary' : 'btn-secondary'" (click)="tab = 'lista'">Solicitudes</button>
    <button [class]="tab === 'nueva' ? 'btn-primary' : 'btn-secondary'" (click)="tab = 'nueva'">Reportar incidencia</button>
    <button [class]="tab === 'costos' ? 'btn-primary' : 'btn-secondary'" (click)="tab = 'costos'; cargarCostos()">Costos por inmueble</button>
  </div>

  <!-- Lista -->
  <div *ngIf="tab === 'lista'" class="luxury-card" style="overflow-x:auto;">
    <label>Estado <select class="modern-input" style="width:auto;display:inline-block;" [(ngModel)]="filtro" (change)="cargar()">
      <option value="">Todos</option><option *ngFor="let e of estados" [value]="e">{{ e }}</option></select></label>
    <table style="margin-top:1rem;">
      <thead><tr><th>#</th><th>Inmueble</th><th>Solicitud</th><th>Categoría</th><th>Urgencia</th><th>Estado</th><th>Responsable</th><th>Costo</th></tr></thead>
      <tbody>
        <tr *ngFor="let s of solicitudes" (click)="abrir(s.id)" style="cursor:pointer;">
          <td>{{ s.id }}</td><td>{{ s.propiedad }}</td><td><b>{{ s.titulo }}</b><br><small style="color:var(--text-muted);">{{ s.reportante }} · {{ s.creado + 'Z' | date:'dd/MM HH:mm' }}</small></td>
          <td>{{ s.categoria }}<br><small style="color:var(--text-muted);">{{ s.clasificacion_modo === 'gemini' ? 'IA' : 'reglas' }}</small></td>
          <td><span class="urg" [ngClass]="s.urgencia">{{ s.urgencia }}</span></td><td>{{ s.estado }}</td><td>{{ s.responsable || '—' }}</td>
          <td>{{ +s.costo_total | number:'1.2-2' }}</td>
        </tr>
        <tr *ngIf="!solicitudes.length"><td colspan="8" style="color:var(--text-muted);">No hay solicitudes.</td></tr>
      </tbody>
    </table>
  </div>

  <!-- Nueva -->
  <form *ngIf="tab === 'nueva'" class="luxury-card" (ngSubmit)="crear()" style="display:grid;gap:0.75rem;max-width:700px;">
    <select class="modern-input" name="p" [(ngModel)]="nueva.id_propiedad" required>
      <option [ngValue]="null">Seleccione el inmueble</option>
      <option *ngFor="let p of inmuebles" [ngValue]="p.id_propiedad">{{ p.titulo }} — {{ p.direccion }}</option>
    </select>
    <p *ngIf="!inmuebles.length" style="color:var(--text-muted);font-size:0.85rem;margin:0;">No tiene inmuebles asociados (como personal, propietario o inquilino con contrato).</p>
    <input class="modern-input" name="t" [(ngModel)]="nueva.titulo" placeholder="Título (ej. Fuga en el baño)" required maxlength="150">
    <textarea class="modern-input" name="d" rows="4" [(ngModel)]="nueva.descripcion" placeholder="Describa el problema" required></textarea>
    <div><button type="button" class="btn-secondary" (click)="previsualizar()" [disabled]="!nueva.titulo && !nueva.descripcion">Ver clasificación automática</button></div>
    <div *ngIf="preview" style="background:#faf5ff;border:1px solid #e9d5ff;border-radius:8px;padding:0.75rem;font-size:0.9rem;">
      Categoría <b>{{ preview.categoria }}</b> · urgencia <span class="urg" [ngClass]="preview.urgencia">{{ preview.urgencia }}</span>
      <small style="color:var(--text-muted);">({{ preview.modo === 'gemini' ? 'Gemini' : 'reglas locales' }}) {{ preview.justificacion }}</small>
    </div>
    <label>Fotos de evidencia (máx. 5 MB c/u) <input type="file" multiple accept="image/png,image/jpeg,image/webp" (change)="fotos = $any($event.target).files"></label>
    <button class="btn-primary" [disabled]="ocupado || !nueva.id_propiedad">Enviar solicitud</button>
  </form>

  <!-- Costos -->
  <div *ngIf="tab === 'costos'" class="luxury-card">
    <h3 style="margin-top:0;">Costos consolidados · total {{ +(costos?.total_general || 0) | number:'1.2-2' }}</h3>
    <table>
      <thead><tr><th>Inmueble</th><th>Solicitudes</th><th>Abiertas</th><th>Costo total</th><th>Por categoría</th></tr></thead>
      <tbody>
        <tr *ngFor="let r of costos?.inmuebles">
          <td>{{ r.propiedad }}</td><td>{{ r.solicitudes }}</td><td>{{ r.abiertas }}</td><td><b>{{ +r.costo_total | number:'1.2-2' }}</b></td>
          <td><span *ngFor="let c of entradas(r.por_categoria)" style="margin-right:0.75rem;">{{ c[0] }}: {{ +c[1] | number:'1.2-2' }}</span></td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Detalle -->
  <div class="panel" *ngIf="sel">
    <div style="display:flex;justify-content:space-between;align-items:center;">
      <h3 style="margin:0;">#{{ sel.id }} {{ sel.titulo }}</h3><button class="btn-secondary" (click)="sel = null">Cerrar</button>
    </div>
    <p style="color:var(--text-muted);font-size:0.9rem;">{{ sel.propiedad }} · reportó {{ sel.reportante }}</p>
    <p>{{ sel.descripcion }}</p>
    <p><span class="urg" [ngClass]="sel.urgencia">{{ sel.urgencia }}</span> {{ sel.categoria }} · <b>{{ sel.estado }}</b> · responsable {{ sel.responsable || '—' }}</p>
    <p *ngIf="sel.justificacion" style="font-size:0.8rem;color:var(--text-muted);">Clasificación ({{ sel.clasificacion_modo }}): {{ sel.justificacion }}</p>
    <div style="display:flex;gap:0.5rem;flex-wrap:wrap;margin-bottom:1rem;">
      <a *ngFor="let f of sel.fotos" [href]="imageUrl(f.url)" target="_blank"><img [src]="imageUrl(f.url)" alt="Evidencia" style="width:90px;height:70px;object-fit:cover;border-radius:6px;"></a>
    </div>
    <label style="font-size:0.85rem;">Agregar foto <input type="file" accept="image/png,image/jpeg,image/webp" (change)="subirFoto($event)"></label>

    <ng-container *ngIf="staff">
      <h4>Gestionar</h4>
      <div style="display:flex;gap:0.4rem;flex-wrap:wrap;">
        <button *ngFor="let e of siguientes(sel.estado)" class="btn-secondary" (click)="cambiar({ estado: e })">→ {{ e }}</button>
      </div>
      <label>Responsable
        <select class="modern-input" [ngModel]="sel.id_responsable" (ngModelChange)="cambiar({ id_responsable: $event })">
          <option *ngFor="let a of personal" [ngValue]="a.ci_usuario">{{ a.nombre }}</option>
        </select></label>
      <label>Urgencia
        <select class="modern-input" [ngModel]="sel.urgencia" (ngModelChange)="cambiar({ urgencia: $event })">
          <option *ngFor="let u of urgencias" [value]="u">{{ u }}</option>
        </select></label>
      <h4>Costos · total {{ +sel.costo_total | number:'1.2-2' }}</h4>
      <div *ngFor="let c of sel.costos" style="display:flex;justify-content:space-between;font-size:0.9rem;">
        <span>{{ c.concepto }}</span><span>{{ +c.monto | number:'1.2-2' }} <button class="btn-secondary" style="padding:0 6px;" (click)="borrarCosto(c)">×</button></span>
      </div>
      <div style="display:flex;gap:0.4rem;margin-top:0.5rem;">
        <input class="modern-input" [(ngModel)]="costo.concepto" placeholder="Concepto">
        <input class="modern-input" type="number" [(ngModel)]="costo.monto" placeholder="Monto" style="width:110px;">
        <button class="btn-primary" (click)="agregarCosto()" [disabled]="!costo.concepto || !costo.monto">+</button>
      </div>
    </ng-container>

    <label *ngIf="staff">Contratista
      <input class="modern-input" [ngModel]="sel.contratista" (ngModelChange)="sel.contratista = $event">
      <button class="btn-secondary" (click)="cambiar({contratista: sel.contratista})">Guardar contratista</button>
    </label>
    <h4>Historial del workflow</h4>
    <div *ngFor="let ev of sel.eventos" style="font-size:0.8rem;border-left:3px solid #a855f7;padding-left:0.6rem;margin-bottom:0.5rem;">
      <b>{{ ev.estado }}</b> · {{ ev.fecha + 'Z' | date:'dd/MM/yy HH:mm' }}<br><span style="color:var(--text-muted);">{{ ev.detalle }}</span>
    </div>
  </div>
</div>`,
})
export class Mantenimiento implements OnInit {
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  api = API;
  imageUrl(url: string) { return /^(https?:|data:)/.test(url) ? url : API + url; }
  staff = tienePermiso('UI:MENU_PROPIEDADES');
  tab: 'lista' | 'nueva' | 'costos' = 'lista';
  estados = ['Recibida', 'Asignada', 'En progreso', 'Resuelta', 'Cerrada', 'Rechazada'];
  urgencias = ['Baja', 'Media', 'Alta', 'Critica'];
  transiciones: Record<string, string[]> = {
    'Recibida': ['Asignada', 'Rechazada'], 'Asignada': ['En progreso', 'Resuelta', 'Rechazada'],
    'En progreso': ['Resuelta', 'Asignada'], 'Resuelta': ['Cerrada', 'En progreso'], 'Cerrada': [], 'Rechazada': [],
  };
  filtro = '';
  solicitudes: any[] = [];
  inmuebles: any[] = [];
  personal: any[] = [];
  costos: any = null;
  sel: any = null;
  preview: any = null;
  nueva: any = { id_propiedad: null, titulo: '', descripcion: '' };
  fotos: FileList | null = null;
  costo: any = { concepto: '', monto: null };
  mensaje = '';
  ocupado = false;

  ngOnInit() {
    this.cargar();
    this.http.get<any[]>(API + '/api/mantenimiento/mis-inmuebles', { headers: authHeaders() }).subscribe(i => { this.inmuebles = i; this.cdr.detectChanges(); });
    if (this.staff) this.http.get<any[]>(API + '/modulo_inmuebles/agentes', { headers: authHeaders() }).subscribe(a => this.personal = a);
  }

  private avisar(t: string) { this.mensaje = t; this.ocupado = false; this.cdr.detectChanges(); }
  entradas(o: any): [string, any][] { return Object.entries(o || {}); }
  siguientes(e: string) { return this.transiciones[e] || []; }

  cargar() {
    const params: any = this.filtro ? { estado: this.filtro } : {};
    this.http.get<any[]>(API + '/api/mantenimiento', { headers: authHeaders(), params }).subscribe({
      next: s => { this.solicitudes = s; this.cdr.detectChanges(); },
      error: e => this.avisar(errorTexto(e, 'No se pudieron cargar las solicitudes.')),
    });
  }

  cargarCostos() {
    this.http.get<any>(API + '/api/mantenimiento/costos/resumen', { headers: authHeaders() }).subscribe(c => { this.costos = c; this.cdr.detectChanges(); });
  }

  previsualizar() {
    this.http.post<any>(API + '/api/mantenimiento/clasificar', { texto: `${this.nueva.titulo}. ${this.nueva.descripcion}` }, { headers: authHeaders() })
      .subscribe({ next: p => { this.preview = p; this.cdr.detectChanges(); }, error: e => this.avisar(errorTexto(e, 'No se pudo clasificar.')) });
  }

  crear() {
    this.ocupado = true;
    this.http.post<any>(API + '/api/mantenimiento', this.nueva, { headers: authHeaders() }).subscribe({
      next: async s => {
        const archivos = Array.from(this.fotos || []);
        for (const f of archivos) await this.enviarFoto(s.id, f).catch(() => this.avisar('Algunas fotos no se pudieron subir.'));
        this.avisar(`Solicitud #${s.id} registrada: ${s.categoria}, urgencia ${s.urgencia}. ` +
          (s.responsable ? `Asignada automáticamente a ${s.responsable}.` : 'Pendiente de asignación.'));
        this.nueva = { id_propiedad: null, titulo: '', descripcion: '' };
        this.preview = null; this.fotos = null; this.tab = 'lista';
        this.cargar();
      },
      error: e => this.avisar(errorTexto(e, 'No se pudo registrar la solicitud.')),
    });
  }

  private enviarFoto(id: number, file: File) {
    const fd = new FormData();
    fd.append('file', file);
    return new Promise((ok, fail) => this.http.post(`${API}/api/mantenimiento/${id}/fotos`, fd, { headers: authHeaders() }).subscribe({ next: ok, error: fail }));
  }

  abrir(id: number) {
    this.http.get<any>(`${API}/api/mantenimiento/${id}`, { headers: authHeaders() }).subscribe(s => { this.sel = s; this.cdr.detectChanges(); });
  }

  subirFoto(ev: any) {
    const f: File | undefined = ev.target.files?.[0];
    ev.target.value = '';
    if (!f || !this.sel) return;
    this.enviarFoto(this.sel.id, f).then(() => this.abrir(this.sel.id), e => this.avisar(errorTexto(e, 'No se pudo subir la foto.')));
  }

  cambiar(body: any) {
    this.http.put<any>(`${API}/api/mantenimiento/${this.sel.id}`, body, { headers: authHeaders() }).subscribe({
      next: s => { this.sel = s; this.avisar('Solicitud actualizada.'); this.cargar(); },
      error: e => this.avisar(errorTexto(e, 'No se pudo actualizar.')),
    });
  }

  agregarCosto() {
    this.http.post<any>(`${API}/api/mantenimiento/${this.sel.id}/costos`, this.costo, { headers: authHeaders() }).subscribe({
      next: s => { this.sel = s; this.costo = { concepto: '', monto: null }; this.cargar(); this.cdr.detectChanges(); },
      error: e => this.avisar(errorTexto(e, 'No se pudo registrar el costo.')),
    });
  }

  borrarCosto(c: any) {
    this.http.delete<any>(`${API}/api/mantenimiento/${this.sel.id}/costos/${c.id}`, { headers: authHeaders() }).subscribe(s => { this.sel = s; this.cargar(); });
  }
}
