import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from '../../../environments/environment';
import { AuthService } from '../../core/services/auth.service';

/** Agenda de visitas: el administrador ve las de su empresa y el agente solo las asignadas a él. */
@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-visitas',
  template: `
<div class="animate-fade-in" style="padding:2rem;">
  <h2 style="color:var(--secondary-color);">Agenda de visitas</h2>
  <div class="luxury-card" style="display:flex;gap:1rem;align-items:flex-end;flex-wrap:wrap;margin-bottom:1.5rem;">
    <label>Estado
      <select class="modern-input" [(ngModel)]="filtroEstado" (change)="cargar()">
        <option value="">Todas</option>
        <option *ngFor="let e of estados" [value]="e">{{ e }}</option>
      </select>
    </label>
    <button class="btn-secondary" (click)="cargar()" [disabled]="cargando">Actualizar</button>
  </div>
  <p *ngIf="mensaje" role="status" style="font-weight:600;">{{ mensaje }}</p>
  <p *ngIf="!cargando && !visitas.length">No hay visitas para mostrar.</p>
  <div class="luxury-card" *ngIf="visitas.length" style="padding:0;overflow-x:auto;">
    <table style="width:100%;border-collapse:collapse;">
      <thead><tr style="border-bottom:2px solid var(--border-light);text-align:left;">
        <th style="padding:1rem;">Fecha</th><th style="padding:1rem;">Inmueble</th><th style="padding:1rem;">Cliente</th>
        <th style="padding:1rem;">Agente</th><th style="padding:1rem;">Estado</th><th style="padding:1rem;">Acciones</th>
      </tr></thead>
      <tbody>
        <tr *ngFor="let v of visitas" style="border-bottom:1px solid var(--border-light);">
          <td style="padding:1rem;">{{ v.fecha_hora | date:'dd/MM/yyyy HH:mm' }}</td>
          <td style="padding:1rem;">{{ v.propiedad }}<br><small style="color:var(--text-muted);">{{ v.direccion }}</small></td>
          <td style="padding:1rem;">{{ v.cliente }}<br><small style="color:var(--text-muted);">{{ v.telefono_cliente }}</small></td>
          <td style="padding:1rem;">{{ v.agente }}</td>
          <td style="padding:1rem;">{{ v.estado }}</td>
          <td style="padding:1rem;">
            <ng-container *ngIf="activa(v); else cerrada">
              <div style="display:flex;gap:0.4rem;flex-wrap:wrap;">
                <button *ngIf="staff && v.estado === 'Programada'" class="btn-primary" (click)="cambiar(v, 'Confirmada')" [disabled]="ocupado">Confirmar</button>
                <button *ngIf="staff" class="btn-secondary" (click)="cambiar(v, 'Realizada')" [disabled]="ocupado">Realizada</button>
                <button *ngIf="staff" class="btn-secondary" (click)="cambiar(v, 'No asistio')" [disabled]="ocupado">No asistió</button>
                <button class="btn-secondary" style="color:#dc2626;" (click)="cambiar(v, 'Cancelada')" [disabled]="ocupado">Cancelar</button>
              </div>
              <div *ngIf="staff" style="display:flex;gap:0.4rem;margin-top:0.5rem;">
                <input type="datetime-local" class="modern-input" [(ngModel)]="nuevaFecha[v.id_visita]" aria-label="Nueva fecha">
                <button class="btn-secondary" (click)="reprogramar(v)" [disabled]="ocupado || !nuevaFecha[v.id_visita]">Reprogramar</button>
              </div>
            </ng-container>
            <ng-template #cerrada><span style="color:var(--text-muted);">Cerrada</span></ng-template>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>`,
})
export class Visitas implements OnInit {
  private auth = inject(AuthService);
  get staff() { const u=this.auth.currentUser(); return u?.id_rol===1 || u?.id_rol===2 || u?.es_agente; }
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  private base = environment.apiUrl + '/api/visitas';
  estados = ['Programada', 'Confirmada', 'Realizada', 'No asistio', 'Cancelada'];
  visitas: any[] = [];
  filtroEstado = '';
  nuevaFecha: Record<number, string> = {};
  cargando = false;
  ocupado = false;
  mensaje = '';

  private headers() {
    return new HttpHeaders().set('Authorization', 'Bearer ' + localStorage.getItem('token'));
  }

  ngOnInit() { this.cargar(); }

  activa(v: any) { return v.estado === 'Programada' || v.estado === 'Confirmada'; }

  cargar() {
    this.cargando = true;
    const params: any = this.filtroEstado ? { estado: this.filtroEstado } : {};
    this.http.get<any[]>(this.base, { headers: this.headers() }).subscribe({
      next: d => { this.visitas = this.filtroEstado ? d.filter(v=>v.estado===this.filtroEstado) : d; this.cargando = false; this.cdr.detectChanges(); },
      error: e => this.error(e),
    });
  }

  cambiar(v: any, estado: string) {
    if (estado === 'Cancelada' && !confirm('¿Cancelar esta visita?')) return;
    this.actualizar(v, { estado }, 'Visita actualizada.');
  }

  reprogramar(v: any) {
    // datetime-local no tiene zona: se envía en ISO con la zona del navegador.
    const fecha = new Date(this.nuevaFecha[v.id_visita]).toISOString();
    this.actualizar(v, { fecha_hora: fecha }, 'Visita reprogramada.');
  }

  private actualizar(v: any, body: any, ok: string) {
    this.ocupado = true;
    this.http.put(`${this.base}/${v.id_visita}`, body, { headers: this.headers() }).subscribe({
      next: (r:any) => { this.ocupado = false; this.mensaje = r?.pendiente ? 'Cambio guardado; pendiente de sincronizar.' : ok; delete this.nuevaFecha[v.id_visita]; this.cargar(); },
      error: e => this.error(e),
    });
  }

  private error(e: any) {
    this.cargando = false;
    this.ocupado = false;
    this.mensaje = typeof e.error?.detail === 'string' ? e.error.detail : 'No se pudo completar la operación.';
    this.cdr.detectChanges();
  }
}
