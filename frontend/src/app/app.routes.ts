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
import { GeneradorReportes } from './features/reportes/generador/generador';
import { Backup } from './features/admin/backup/backup';

import { permissionGuard } from './core/guards/permission.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: Login },
  { path: 'forgot-password', component: ForgotPassword },
  { 
    path: 'dashboard', 
    component: Layout,
    children: [
      { path: 'catalogo', component: Catalogo },
      { path: 'profile', component: Profile },
      { path: 'empresas', component: Empresas, canActivate: [permissionGuard('UI:MENU_EMPRESAS')] },
      { path: 'usuarios', component: Usuarios, canActivate: [permissionGuard('UI:MENU_USUARIOS')] },
      { path: 'roles', component: Roles, canActivate: [permissionGuard('UI:MENU_ROLES')] },
      { path: 'reportes', component: GeneradorReportes },
      { path: 'backup', component: Backup },
      { path: 'bitacora', component: Bitacora, canActivate: [permissionGuard('UI:MENU_BITACORA')] },
      { path: 'clientes', component: Clientes, canActivate: [permissionGuard('UI:MENU_CLIENTES')] },
      { path: 'propietarios', component: Propietarios, canActivate: [permissionGuard('UI:MENU_PROPIETARIOS')] },
      { path: 'agentes', component: Agentes, canActivate: [permissionGuard('UI:MENU_AGENTES')] },
      { path: 'propiedades', component: Propiedades, canActivate: [permissionGuard('UI:MENU_PROPIEDADES')] }
    ]
  }
];
