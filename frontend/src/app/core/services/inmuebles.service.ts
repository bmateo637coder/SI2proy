import { Injectable } from '@angular/core';
import { BehaviorSubject, forkJoin } from 'rxjs';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { AuthService } from './auth.service';
import { environment } from '../../../environments/environment';

const CACHE_TTL_MS = 60000;

@Injectable({
  providedIn: 'root',
})
export class InmueblesService {
  private apiBase = environment.apiUrl;

  clientes$ = new BehaviorSubject<any[]>([]);
  propiedades$ = new BehaviorSubject<any[]>([]);
  cargando = false;
  private ultimaCarga: number = 0;

  constructor(private http: HttpClient, private authService: AuthService) {}

  private getHeaders() {
    const token = localStorage.getItem('token');
    let headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    const user = this.authService.currentUser();
    if (user && user.id_tenant) {
      headers = headers.set('X-Tenant-ID', user.id_tenant.toString());
    }
    return headers;
  }

  cargar(force = false) {
    const clientes = this.clientes$.getValue();
    const propiedades = this.propiedades$.getValue();
    const fresco = this.ultimaCarga && Date.now() - this.ultimaCarga < CACHE_TTL_MS;
    if (!force && fresco && (clientes.length > 0 || propiedades.length > 0)) return;
    if (this.cargando) return;
    this.cargando = true;

    forkJoin({
      clientes: this.http.get(`${this.apiBase}/modulo_inmuebles/clientes`, { headers: this.getHeaders() }),
      propiedades: this.http.get(`${this.apiBase}/modulo_inmuebles/propiedades`, { headers: this.getHeaders() }),
    }).subscribe({
      next: ({ clientes, propiedades }) => {
        this.clientes$.next(clientes || []);
        this.propiedades$.next((propiedades || []).filter((p: any) => ['Disponible', 'Reservada'].includes(p.estado)));
        this.ultimaCarga = Date.now();
        this.cargando = false;
      },
      error: () => {
        this.cargando = false;
      },
    });
  }

  invalidar() {
    this.ultimaCarga = 0;
  }
}