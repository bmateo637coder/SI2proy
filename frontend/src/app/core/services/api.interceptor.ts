import { inject } from '@angular/core';
import { HttpInterceptorFn } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthService } from './auth.service';
import { ApiFeedback } from './api-feedback.service';

export const apiInterceptor: HttpInterceptorFn = (request, next) => {
  if (!request.url.startsWith(environment.apiUrl + '/')) return next(request);
  const auth = inject(AuthService);
  const feedback = inject(ApiFeedback);
  const token = localStorage.getItem('token');
  const tid = auth.tenantId();
  if (token && !request.url.endsWith('/login')) {
    request = request.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
  }
  if (tid && !request.url.endsWith('/users/me')) {
    request = request.clone({ setHeaders: { 'X-Tenant-ID': String(tid) } });
    // Compatibilidad con los listados que reciben la empresa como query parameter.
    if (auth.currentUser()?.id_rol === 1 && request.method === 'GET' &&
        /\/modulo_inmuebles\/(propiedades|clientes|agentes|propietarios)$/.test(request.url) &&
        !request.params.has('id_tenant')) {
      request = request.clone({ setParams: { id_tenant: String(tid) } });
    }
  }
  return next(request).pipe(catchError(error => {
    if (!request.url.endsWith('/login')) {
      if (error.status === 401) auth.logout('expired');
      else {
        const detail = error.error?.detail;
        feedback.error.set(typeof detail === 'string' ? detail : error.status === 0
          ? 'No se pudo conectar con el servidor. Revisa tu conexión y vuelve a intentar.'
          : error.status === 422 ? 'Revisa los campos y filtros ingresados.'
          : 'No se pudo completar la solicitud. Vuelve a intentar en unos momentos.');
      }
    }
    return throwError(() => error);
  }));
};
