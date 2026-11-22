import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { Subscription } from 'rxjs';
import { errorTexto } from '../../core/services/api';
import { environment } from '../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-catalogo',
  templateUrl: './catalogo.html',
})
export class Catalogo implements OnInit, OnDestroy {
  mensajeFavorito = '';
  guardarFavorito(prop: any) {
    this.http.post<any>(`${this.apiBase}/api/favoritos/${prop.id_propiedad}`, {}).subscribe({
      next: r => { this.mensajeFavorito = r.pendiente ? 'Favorito guardado en este navegador; pendiente de sincronización.' : 'Favorito guardado.'; this.cdr.markForCheck(); },
      error: () => { this.mensajeFavorito = 'No se pudo guardar el favorito. Revisa la sincronización.'; this.cdr.markForCheck(); }
    });
  }
  loading = false;
  error = '';
  private catalogRequest?: Subscription;
  private recommendationsRequest?: Subscription;
  propiedades: any[] = [];
  recomendados: any[] = [];
  private apiBase = environment.apiUrl;
  private ws: WebSocket | null = null;
  private reconnectTimer?: ReturnType<typeof setTimeout>;
  private destroyed = false;

  filtroOperacion: string = '';
  filtroPrecioMin: number | null = null;
  filtroPrecioMax: number | null = null;

  // Advanced filters
  filtroCuartos: number | null = null;
  filtroBanos: number | null = null;
  filtroSalas: number | null = null;
  filtroMetrosMin: number | null = null;
  filtroMetrosMax: number | null = null;
  filtroZona: string = '';
  filtroAmueblado: boolean = false;
  filtroServicios: boolean = false;
  mostrarFiltrosAvanzados: boolean = false;

  // Detalle Modal
  propiedadSeleccionada: any = null;
  mostrarModalDetalle: boolean = false;

  toggleFiltrosAvanzados() {
    this.mostrarFiltrosAvanzados = !this.mostrarFiltrosAvanzados;
  }

  abrirDetalles(prop: any) {
    this.propiedadSeleccionada = this.propiedades.find(p => p.id_propiedad === prop.id_propiedad) || prop;
    this.mostrarModalDetalle = true;
  }

  cerrarDetalles() {
    this.mostrarModalDetalle = false;
    this.propiedadSeleccionada = null;
  }

  imageUrl(url: string | null | undefined): string {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return new URL(url, this.apiBase + '/').href;
  }

  constructor(private http: HttpClient, public authService: AuthService, private cdr: ChangeDetectorRef) {}

  ngOnInit() {
    this.aplicarFiltros();
    this.cargarRecomendados();
    this.connectWebSocket();
  }

  cargarRecomendados() {
    let headers = new HttpHeaders();
    const user = this.authService.currentUser();
    if (user && user.id_tenant) {
        headers = headers.set('X-Tenant-ID', user.id_tenant.toString());
    }
    this.recommendationsRequest = this.http.post<any>(`${environment.apiUrl}/api/ia/recomendar`, { limite: 4 }, { headers })
      .subscribe({
        next: (res: any) => {
          const recs = res?.recomendaciones || res?.data || [];
          this.recomendados = recs.map((r: any) => ({
            ...r,
            imagenes: r.imagen ? [{ url: r.imagen }] : [],
            caracteristicas: r.caracteristicas || [],
          }));
          this.cdr.detectChanges();
        },
        error: () => {},
      });
  }

  connectWebSocket() {
    if (this.destroyed || (!this.authService.tenantId() && !this.authService.allTenants())) return;
    const scope = this.authService.allTenants() ? 'scope=all' : `id_tenant=${this.authService.tenantId()}`;
    this.ws = new WebSocket(`${environment.wsUrl}/ws/propiedades?${scope}`, ['raices', localStorage.getItem('token') || 'missing']);
    this.ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.event === 'estado_updated') {
          // Update the UI
          const propIndex = this.propiedades.findIndex(p => p.id_propiedad === data.id_propiedad);
          if (propIndex !== -1) {
            this.propiedades[propIndex].estado = data.nuevo_estado;
            this.cdr.detectChanges();
          }
          // If modal is open for this property, update it too
          if (this.propiedadSeleccionada && this.propiedadSeleccionada.id_propiedad === data.id_propiedad) {
            this.propiedadSeleccionada.estado = data.nuevo_estado;
            this.cdr.detectChanges();
          }
        }
      } catch (e) {
        console.error("Error parsing WS message", e);
      }
    };
    this.ws.onclose = event => {
      if (!this.destroyed && event.code !== 1008) this.reconnectTimer = setTimeout(() => this.connectWebSocket(), 5000);
    };
  }

  ngOnDestroy() {
    this.destroyed = true;
    this.catalogRequest?.unsubscribe();
    this.recommendationsRequest?.unsubscribe();
    clearTimeout(this.reconnectTimer);
    if (this.ws) {
      this.ws.onclose = null; // Prevent auto-reconnect
      this.ws.close();
    }
  }

  aplicarFiltros() {
    this.catalogRequest?.unsubscribe();
    this.loading = false;
    this.error = '';
    for (const [min, max, label] of [[this.filtroPrecioMin, this.filtroPrecioMax, 'precio'], [this.filtroMetrosMin, this.filtroMetrosMax, 'superficie']] as const) {
      if ((min != null && (!Number.isFinite(min) || min < 0)) || (max != null && (!Number.isFinite(max) || max < 0)) || (min != null && max != null && min > max)) {
        this.error = `Revisa el rango de ${label}: usa valores positivos y un mínimo menor o igual al máximo.`;
        this.propiedades = [];
        return;
      }
    }
    this.loading = true;
    let params: any = {};
    if (this.filtroOperacion) params.tipo_operacion = this.filtroOperacion;
    if (this.filtroPrecioMin != null) params.precio_min = this.filtroPrecioMin;
    if (this.filtroPrecioMax != null) params.precio_max = this.filtroPrecioMax;

    // Advanced filters
    if (this.filtroCuartos) params.cuartos = this.filtroCuartos;
    if (this.filtroBanos) params.banos = this.filtroBanos;
    if (this.filtroSalas) params.salas = this.filtroSalas;
    if (this.filtroMetrosMin != null) params.metros_min = this.filtroMetrosMin;
    if (this.filtroMetrosMax != null) params.metros_max = this.filtroMetrosMax;
    if (this.filtroZona) params.zona = this.filtroZona;
    if (this.filtroAmueblado) params.amueblado = this.filtroAmueblado;
    if (this.filtroServicios) params.servicios_basicos = this.filtroServicios;

    let headers = new HttpHeaders();
    const user = this.authService.currentUser();
    if (user && user.id_tenant) {
        headers = headers.set('X-Tenant-ID', user.id_tenant.toString());
    }

    this.catalogRequest = this.http.get<any[]>(`${environment.apiUrl}/modulo_inmuebles/propiedades/catalogo`, { params, headers })
      .subscribe({
        next: (res: any[]) => {
          this.propiedades = [...res];
          this.loading = false;
          this.cdr.detectChanges();
        },
        error: (err) => {
          this.loading = false;
          this.propiedades = [];
          this.error = errorTexto(err, 'No se pudo cargar el catálogo. Vuelve a aplicar los filtros para reintentar.');
          this.cdr.detectChanges();
        }
      });
  }
}
