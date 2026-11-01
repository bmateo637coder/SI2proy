import { Routes } from '@angular/router';
import { Login } from './features/usuarios/login/login';
import { Layout } from './components/layout/layout';
import { ForgotPassword } from './components/forgot-password/forgot-password';
import { Profile } from './components/profile/profile';
import { Roles } from './features/usuarios/roles/roles';
import { Clientes } from './features/inmuebles/clientes/clientes';
import { Propietarios } from './features/inmuebles/propietarios/propietarios';
import { Agentes } from './features/inmuebles/agentes/agentes';
import { Propiedades } from './features/inmuebles/propiedades/propiedades';
import { Catalogo } from './components/catalogo/catalogo';
import { Usuarios } from './features/usuarios/usuarios/usuarios';
import { Bitacora } from './features/admin/bitacora/bitacora';
import { Empresas } from './features/admin/empresas/empresas';
import { Backup } from './features/admin/backup/backup';
import { Contratos } from './features/gestion-contractual/contratos/contratos';

import { permissionGuard } from './core/guards/permission.guard';
import { sessionGuard, staffGuard, superAdminGuard } from './core/guards/session.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: Login },
  { path: 'forgot-password', component: ForgotPassword },
  {
    path: 'dashboard',
    component: Layout,
    canActivate: [sessionGuard],
    children: [
      { path: 'vista-global', canActivate: [superAdminGuard], loadComponent: () => import('./features/admin/vista-global/vista-global').then(m => m.VistaGlobalPage) },
      { path: 'offline', canActivate: [staffGuard], loadComponent: () => import('./features/offline/offline').then(m => m.OfflinePage) },
      { path: 'analitica', canActivate: [staffGuard], loadComponent: () => import('./features/analitica/analitica').then(m => m.AnaliticaPage) },
      { path: 'plan', canActivate: [staffGuard], loadComponent: () => import('./features/saas/saas').then(m => m.SaasPage) },
      { path: 'catalogo', component: Catalogo },
      { path: 'profile', component: Profile },
      { path: 'empresas', component: Empresas, canActivate: [permissionGuard('UI:MENU_EMPRESAS')] },
      { path: 'usuarios', component: Usuarios, canActivate: [permissionGuard('UI:MENU_USUARIOS')] },
      { path: 'roles', component: Roles, canActivate: [permissionGuard('UI:MENU_ROLES')] },
      { path: 'reportes', loadComponent: () => import('./features/reportes/generador/generador').then(m => m.GeneradorReportes) },
      { path: 'backup', component: Backup },
      { path: 'bitacora', component: Bitacora, canActivate: [permissionGuard('UI:MENU_BITACORA')] },
      { path: 'clientes', component: Clientes, canActivate: [permissionGuard('UI:MENU_CLIENTES')] },
      { path: 'propietarios', component: Propietarios, canActivate: [permissionGuard('UI:MENU_PROPIETARIOS')] },
      { path: 'agentes', component: Agentes, canActivate: [permissionGuard('UI:MENU_AGENTES')] },
      { path: 'propiedades', component: Propiedades, canActivate: [permissionGuard('UI:MENU_PROPIEDADES')] },
      { path: 'contratos', component: Contratos, canActivate: [permissionGuard('UI:MENU_PROPIEDADES')] }
    ]
  }
];
