import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { OfflineService, LocalOperation } from '../../core/services/offline.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './offline.html',
  styleUrl: '../parcial2.css'
})
export class OfflinePage implements OnInit {
  readonly service = inject(OfflineService);
  readonly auth = inject(AuthService);
  readonly data = signal<any>(null);
  readonly operations = signal<LocalOperation[]>([]);
  readonly message = signal('');
  readonly busy = signal(false);
  clientId = 0;
  branchId = 0;
  async ngOnInit() { if (!this.auth.allTenants()) await this.reload(); }
  async reload() {
    try {
      this.data.set(await this.service.snapshot());
      this.operations.set(await this.service.operations());
    } catch (e: any) { this.message.set(e.message); }
  }
  async action(work: () => Promise<unknown>) {
    this.busy.set(true);
    this.message.set('');
    try { await work(); await this.reload(); }
    catch (e: any) { this.message.set(typeof e.error?.detail === 'string' ? e.error.detail : e.message || 'No se completó la operación.'); }
    finally { this.busy.set(false); }
  }
  download() { return this.action(() => this.service.download()); }
  sync() { return this.action(() => this.service.synchronize()); }
  cancel(op: LocalOperation) { return this.action(() => this.service.cancel(op)); }
  register(prop: any, tipo: 'reserva' | 'venta_contado') {
    return this.action(async () => {
      await this.service.queue(prop, Number(this.clientId), tipo);
      this.message.set('Guardada en este dispositivo. Pendiente de confirmación del servidor.');
    });
  }
  get properties() { return (this.data()?.propiedades || []).filter((p: any) => !this.branchId || p.id_sucursal === Number(this.branchId)); }
}
