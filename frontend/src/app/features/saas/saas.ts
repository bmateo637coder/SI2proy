import { Component, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/services/auth.service';
import { environment } from '../../../environments/environment';

@Component({ standalone: true, imports: [CommonModule, FormsModule], templateUrl: './saas.html', styleUrl: '../parcial2.css' })
export class SaasPage implements OnInit {
  private http = inject(HttpClient);
  readonly auth = inject(AuthService);
  readonly status = signal<any>(null);
  readonly plans = signal<any[]>([]);
  readonly branches = signal<any[]>([]);
  readonly message = signal('');
  readonly busy = signal(false);
  plan = 'basico'; inicio = ''; vencimiento = ''; estado = 'activa';
  nombre = ''; direccion = ''; ci = ''; sid = 0; pid = 0;
  private headers() { return new HttpHeaders({ Authorization: `Bearer ${localStorage.getItem('token')}` }); }
  private get(path: string) { return firstValueFrom(this.http.get<any>(`${environment.apiUrl}/api/saas/${path}`, { headers: this.headers() })); }
  async ngOnInit() { await this.act(() => this.load()); }
  async load() {
    const [status, plans, branches] = await Promise.all([this.get('suscripcion'), this.get('planes'), this.get('sucursales')]);
    this.status.set(status); this.plans.set(plans); this.branches.set(branches);
    this.plan = status.codigo_plan || 'basico'; this.inicio = status.inicio || ''; this.vencimiento = status.vencimiento || ''; this.estado = ['activa', 'suspendida', 'cancelada'].includes(status.estado) ? status.estado : 'activa';
  }
  async act(work: () => Promise<unknown>) {
    this.busy.set(true); this.message.set('');
    try { await work(); }
    catch (e: any) { this.message.set(typeof e.error?.detail === 'string' ? e.error.detail : 'Revise los campos o la conexión.'); }
    finally { this.busy.set(false); }
  }
  private async save(path: string, data: any, method: 'post' | 'put' = 'post') {
    await firstValueFrom(this.http.request(method, `${environment.apiUrl}/api/saas/${path}`, { body: data, headers: this.headers() }));
    await this.load(); this.message.set('Cambios guardados.');
  }
  subscription() { return this.act(() => this.save(`suscripcion/${this.auth.tenantId()}`, { codigo_plan: this.plan, inicio: this.inicio, vencimiento: this.vencimiento, estado: this.estado }, 'put')); }
  create() { return this.act(async () => { await this.save('sucursales', { nombre: this.nombre, direccion: this.direccion, activa: true }); this.nombre = ''; this.direccion = ''; }); }
  toggle(b: any) { return this.act(() => this.save(`sucursales/${b.id_sucursal}`, { nombre: b.nombre, direccion: b.direccion, activa: !b.activa }, 'put')); }
  assign() { return this.act(() => this.save(`sucursales/${this.sid}/usuarios`, { ci_usuario: this.ci })); }
  property() { return this.act(() => this.save(`propiedades/${this.pid}/sucursal`, { id_sucursal: Number(this.sid) }, 'put')); }
}
