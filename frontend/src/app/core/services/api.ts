import { HttpHeaders } from '@angular/common/http';
import { environment } from '../../../environments/environment';

/** Utilidades comunes para las pantallas del Sprint 4. */
export const API = environment.apiUrl;

export function authHeaders(): HttpHeaders {
  return new HttpHeaders().set('Authorization', 'Bearer ' + (localStorage.getItem('token') || ''));
}

export function errorTexto(e: any, fallback: string): string {
  const d = e?.error?.detail;
  if (typeof d === 'string') return d;
  if (Array.isArray(d) && d[0]?.msg) return d[0].msg;
  return fallback;
}

export function usuarioActual(): any {
  try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; }
}

export function tienePermiso(codigo: string): boolean {
  return (usuarioActual().permisos || []).includes(codigo);
}
