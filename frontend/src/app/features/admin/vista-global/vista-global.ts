import { Component, inject, OnInit, OnDestroy, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { AuthService } from '../../../core/services/auth.service';
import { environment } from '../../../../environments/environment';

type Column = { key: string; label: string; money?: boolean };
type Entity = 'propiedades' | 'clientes' | 'propietarios' | 'agentes' | 'contratos' | 'usuarios' | 'sucursales';
const people: Column[] = [{ key: 'nombre', label: 'Nombre' }, { key: 'ci', label: 'CI' },
  { key: 'correo', label: 'Correo' }, { key: 'telefono', label: 'Teléfono' }];
const columns: Record<Entity, Column[]> = {
  propiedades: [{ key: 'titulo', label: 'Propiedad' }, { key: 'direccion', label: 'Dirección' },
    { key: 'tipo_operacion', label: 'Operación' }, { key: 'estado', label: 'Estado' }, { key: 'precio', label: 'Precio (USD)', money: true }],
  clientes: people, propietarios: people, agentes: people,
  contratos: [{ key: 'id_contrato', label: 'Contrato' }, { key: 'propiedad', label: 'Propiedad' },
    { key: 'tipo_contrato', label: 'Tipo' }, { key: 'monto_total', label: 'Monto (USD)', money: true },
    { key: 'fecha_inicio', label: 'Desde' }, { key: 'fecha_fin', label: 'Hasta' }],
  usuarios: [...people, { key: 'rol', label: 'Rol' }],
  sucursales: [{ key: 'nombre', label: 'Sucursal' }, { key: 'direccion', label: 'Dirección' }, { key: 'activa', label: 'Activa' }]
};

@Component({ standalone: true, imports: [CommonModule, FormsModule], templateUrl: './vista-global.html', styleUrl: './vista-global.css' })
export class VistaGlobalPage implements OnInit, OnDestroy {
  private http = inject(HttpClient);
  private auth = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  readonly resumen = signal<any>(null);
  readonly rows = signal<Record<string, any>[]>([]);
  readonly total = signal(0);
  readonly busy = signal(false);
  readonly loadingSummary = signal(false);
  readonly error = signal('');
  readonly summaryError = signal('');
  readonly entidades: { key: Entity; label: string }[] = [
    { key: 'propiedades', label: 'Propiedades' }, { key: 'clientes', label: 'Clientes' },
    { key: 'propietarios', label: 'Propietarios' }, { key: 'agentes', label: 'Agentes' },
    { key: 'contratos', label: 'Contratos' }, { key: 'usuarios', label: 'Usuarios' }, { key: 'sucursales', label: 'Sucursales' }
  ];
  entidad: Entity = 'propiedades';
  empresa: number | null = null;
  buscar = '';
  offset = 0;
  readonly limite = 50;
  detalle: Record<string, any> | null = null;
  private rowsRequest?: Subscription;
  private summaryRequest?: Subscription;
  private routeRequest?: Subscription;
  get columnas() { return columns[this.entidad]; }
  get label() { return this.entidades.find(e => e.key === this.entidad)!.label; }
  get hasta() { return Math.min(this.offset + this.rows().length, this.total()); }

  ngOnInit() {
    this.loadSummary();
    this.routeRequest = this.route.queryParamMap.subscribe(params => {
      const entity = params.get('entidad');
      this.entidad = this.entidades.find(e => e.key === entity)?.key || 'propiedades';
      this.offset = 0;
      this.loadRows();
    });
  }
  loadSummary() {
    this.summaryRequest?.unsubscribe();
    this.loadingSummary.set(true); this.summaryError.set('');
    this.summaryRequest = this.http.get<any>(`${environment.apiUrl}/admin/vista-global/resumen`).subscribe({
      next: data => { this.resumen.set(data); this.loadingSummary.set(false); },
      error: () => { this.loadingSummary.set(false); this.summaryError.set('No se pudo cargar el resumen. Vuelve a intentar.'); }
    });
  }
  loadRows(reset = false) {
    if (reset) this.offset = 0;
    this.rowsRequest?.unsubscribe();
    this.detalle = null; this.busy.set(true); this.error.set(''); this.rows.set([]); this.total.set(0);
    const params: Record<string, string | number> = { limite: this.limite, offset: this.offset, buscar: this.buscar.trim() };
    if (this.empresa) params['id_tenant'] = this.empresa;
    this.rowsRequest = this.http.get<any>(`${environment.apiUrl}/admin/vista-global/${this.entidad}`, { params }).subscribe({
      next: data => { this.rows.set(data.data); this.total.set(data.total); this.busy.set(false); },
      error: e => { this.busy.set(false); this.error.set(typeof e.error?.detail === 'string' ? e.error.detail : 'No se pudo cargar la información. Revisa tu conexión y vuelve a intentar.'); }
    });
  }
  cambiarEntidad(entity: Entity) {
    this.router.navigate([], { relativeTo: this.route, queryParams: { entidad: entity } });
  }
  filtrarEmpresa(id: number) { this.empresa = id; this.loadRows(true); }
  limpiar() { this.empresa = null; this.buscar = ''; this.loadRows(true); }
  pagina(delta: number) { this.offset = Math.max(0, this.offset + delta * this.limite); this.loadRows(); }
  abrirEmpresa(id: number) {
    this.auth.selectTenant(id);
    this.router.navigate(['/dashboard/catalogo']).then(() => window.location.reload());
  }
  valor(row: Record<string, any>, col: Column): string {
    const value = row[col.key];
    if (value === null || value === undefined || value === '') return '—';
    if (typeof value === 'boolean') return value ? 'Sí' : 'No';
    return col.money ? new Intl.NumberFormat('es-BO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(value)) : String(value);
  }
  imageUrl(url: string) { return url.startsWith('/') ? environment.apiUrl + url : url; }
  private csv(filename: string, data: string[][]) {
    const escape = (value: string) => '"' + (/^[\s]*[=+@\-]/.test(value) ? "'" + value : value).replace(/"/g, '""') + '"';
    const blob = new Blob(['\ufeff' + data.map(row => row.map(escape).join(',')).join('\r\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob); const link = document.createElement('a'); link.href = url; link.download = filename; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  exportSummary() {
    if (!this.resumen()) return;
    this.csv('resumen-inmobiliarias.csv', [['Inmobiliaria', 'Plan', 'Suscripción', ...this.entidades.map(e => e.label)],
      ...this.resumen().empresas.map((e: any) => [e.nombre, e.plan, e.suscripcion, ...this.entidades.map(t => String(e.conteos[t.key]))])]);
  }
  exportPage() {
    this.csv(`${this.entidad}-pagina-${this.offset / this.limite + 1}.csv`, [['Inmobiliaria', ...this.columnas.map(c => c.label)],
      ...this.rows().map(row => [row['inmobiliaria'], ...this.columnas.map(c => this.valor(row, c))])]);
  }
  ngOnDestroy() { this.rowsRequest?.unsubscribe(); this.summaryRequest?.unsubscribe(); this.routeRequest?.unsubscribe(); }
}
