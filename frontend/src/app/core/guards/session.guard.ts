import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

export const sessionGuard: CanActivateFn = () => {
  return inject(AuthService).currentUser() && localStorage.getItem('token') ? true : inject(Router).createUrlTree(['/login']);
};

export const staffGuard: CanActivateFn = () => {
  const user = inject(AuthService).currentUser();
  return (user?.id_rol === 1 && inject(AuthService).tenantId()) || user?.id_tenant && (user.id_rol === 2 || user.es_agente || user.permisos?.includes('API:OPERACIONES'))
    ? true : inject(Router).createUrlTree(['/dashboard/profile']);
};
