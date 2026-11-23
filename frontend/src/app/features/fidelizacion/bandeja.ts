import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { API, authHeaders } from '../../core/services/api';

/** Bandeja de notificaciones in-app (alertas, mantenimiento, prospectos, visitas). */
@Component({
  standalone: true,
  imports: [CommonModule],
  selector: 'app-bandeja',
  template: `
<div class="animate-fade-in" style="padding:2rem;max-width:900px;margin:0 auto;">
  <div style="display:flex;justify-content:space-between;align-items:center;">
    <h2 style="color:var(--secondary-color);">Notificaciones <small *ngIf="noLeidas" style="font-size:0.9rem;color:#e11d48;">({{ noLeidas }} sin leer)</small></h2>
    <button class="btn-secondary" (click)="leerTodas()" [disabled]="!noLeidas">Marcar todas como leídas</button>
  </div>
  <p *ngIf="!items.length" style="color:var(--text-muted);">No tiene notificaciones.</p>
  <div *ngFor="let n of items" class="luxury-card" (click)="abrir(n)"
       style="margin-bottom:0.75rem;padding:1rem 1.25rem;cursor:pointer;display:flex;gap:1rem;align-items:flex-start;"
       [style.borderLeft]="n.leida ? '4px solid transparent' : '4px solid #7e22ce'">
    <span style="font-size:0.7rem;text-transform:uppercase;background:#f1f5f9;padding:2px 8px;border-radius:10px;white-space:nowrap;">{{ n.tipo }}</span>
    <div style="flex:1;">
      <strong [style.fontWeight]="n.leida ? 500 : 700">{{ n.titulo }}</strong>
      <div style="font-size:0.9rem;color:var(--text-muted);">{{ n.cuerpo }}</div>
    </div>
    <small style="color:var(--text-muted);white-space:nowrap;">{{ n.fecha + 'Z' | date:'dd/MM HH:mm' }}</small>
  </div>
</div>`,
})
export class Bandeja implements OnInit {
  private http = inject(HttpClient);
  private cdr = inject(ChangeDetectorRef);
  private router = inject(Router);
  items: any[] = [];
  noLeidas = 0;

  ngOnInit() { this.cargar(); }

  cargar() {
    this.http.get<any>(API + '/api/bandeja', { headers: authHeaders() }).subscribe(r => {
      this.items = r.notificaciones; this.noLeidas = r.no_leidas; this.cdr.detectChanges();
    });
  }

  leerTodas() {
    this.http.put(API + '/api/bandeja/leer-todas', {}, { headers: authHeaders() }).subscribe(() => this.cargar());
  }

  /** Marca como leída y navega a la pantalla relacionada según la referencia. */
  abrir(n: any) {
    const destino: Record<string, string> = {
      alerta: '/dashboard/catalogo', mantenimiento: '/dashboard/mantenimiento',
      prospecto: '/dashboard/crm', visita: '/dashboard/visitas', pago: '/dashboard/mi-alquiler', anticretico: '/dashboard/anticreticos',
      mensaje: '/dashboard/consultas', reserva: '/dashboard/contratos', contrato: '/dashboard/contratos', comision: '/dashboard/comisiones',
    };
    const ir = () => { if (destino[n.tipo]) this.router.navigate([destino[n.tipo]]); };
    if (n.leida) { ir(); return; }
    this.http.put(`${API}/api/bandeja/${n.id}/leida`, {}, { headers: authHeaders() }).subscribe(() => ir());
  }
}
