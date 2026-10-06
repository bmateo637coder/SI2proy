import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  selector: 'app-catalogo',
  templateUrl: './catalogo.html',
})
export class Catalogo implements OnInit, OnDestroy {
  propiedades: any[] = [];
  recomendados: any[] = [];
  private apiBase = 'http://localhost:8000';
  private ws: WebSocket | null = null;
  
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
    this.propiedadSeleccionada = prop;
    this.mostrarModalDetalle = true;
  }

  cerrarDetalles() {
    this.mostrarModalDetalle = false;
    this.propiedadSeleccionada = null;
  }

  imageUrl(url: string | null | undefined): string {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return this.apiBase + url;
  }

  constructor(private http: HttpClient, private authService: AuthService, private cdr: ChangeDetectorRef) {}

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
    this.http.post<any>('http://localhost:8000/api/ia/recomendar', { limite: 4 }, { headers })
      .subscribe({
        next: (res: any) => {
          const recs = res?.recomendaciones || res?.data || [];
          this.recomendados = recs.map((r: any) => ({
            ...r,
            imagenes: r.imagen ? [{ url: r.imagen }] : [],
            caracteristicas: [],
          }));
          this.cdr.detectChanges();
        },
        error: () => {},
      });
  }

  connectWebSocket() {
    this.ws = new WebSocket('ws://localhost:8000/ws/propiedades');
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
    this.ws.onclose = () => {
      console.log('WebSocket connection closed, reconnecting in 5s...');
      setTimeout(() => this.connectWebSocket(), 5000);
    };
  }

  ngOnDestroy() {
    if (this.ws) {
      this.ws.onclose = null; // Prevent auto-reconnect
      this.ws.close();
    }
  }

  aplicarFiltros() {
    let params: any = {};
    if (this.filtroOperacion) params.tipo_operacion = this.filtroOperacion;
    if (this.filtroPrecioMin) params.precio_min = this.filtroPrecioMin;
    if (this.filtroPrecioMax) params.precio_max = this.filtroPrecioMax;
    
    // Advanced filters
    if (this.filtroCuartos) params.cuartos = this.filtroCuartos;
    if (this.filtroBanos) params.banos = this.filtroBanos;
    if (this.filtroSalas) params.salas = this.filtroSalas;
    if (this.filtroMetrosMin) params.metros_min = this.filtroMetrosMin;
    if (this.filtroMetrosMax) params.metros_max = this.filtroMetrosMax;
    if (this.filtroZona) params.zona = this.filtroZona;
    if (this.filtroAmueblado) params.amueblado = this.filtroAmueblado;
    if (this.filtroServicios) params.servicios_basicos = this.filtroServicios;
    
    let headers = new HttpHeaders();
    const user = this.authService.currentUser();
    if (user && user.id_tenant) {
        headers = headers.set('X-Tenant-ID', user.id_tenant.toString());
    }

    this.http.get<any[]>('http://localhost:8000/modulo_inmuebles/propiedades/catalogo', { params, headers })
      .subscribe({
        next: (res: any[]) => {
          this.propiedades = [...res];
          console.log('Propiedades cargadas:', this.propiedades.length);
          this.cdr.detectChanges();
        },
        error: (err) => {
          console.error('Error cargando propiedades:', err);
          this.cdr.detectChanges();
        }
      });
  }
}
