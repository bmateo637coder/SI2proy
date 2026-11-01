import { Component, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { ApiFeedback } from '../../core/services/api-feedback.service';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';
import { HasPermissionDirective } from '../../core/directives/has-permission.directive';
import { AuthService } from '../../core/services/auth.service';
import { InmueblesService } from '../../core/services/inmuebles.service';
import { environment } from '../../../environments/environment';

@Component({
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, CommonModule, FormsModule, HasPermissionDirective],
  selector: 'app-layout',
  styleUrl: './layout.css',
  templateUrl: './layout.html',
})
export class Layout {
  userRole: number = 0;
  rolNombre: string = 'Inmobiliaria';
  tenantNombre: string = '';
  canOperate: boolean = false;
  showHelp: boolean = false;
  buildVersion: string = environment.version;
  empresas = signal<any[]>([]);
  selectedTenant: number | null = null;

  constructor(private router: Router, public authService: AuthService, private inmuebles: InmueblesService,
    public feedback: ApiFeedback, private http: HttpClient) {
    const userRole = localStorage.getItem('user_role');
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    this.tenantNombre = user.id_tenant ? (user.tenant_nombre || `Inmobiliaria #${user.id_tenant}`) : 'Plataforma SaaS';
    this.selectedTenant = user.id_rol === 1 ? authService.selectedTenant() : authService.tenantId();
    this.canOperate = (!!this.selectedTenant || authService.allTenants()) && (user.id_rol === 1 || user.id_rol === 2 || user.es_agente || user.permisos?.includes('API:OPERACIONES'));
    this.userRole = userRole ? parseInt(userRole, 10) : 0;
    this.inmuebles.cargar();
    if (this.userRole === 1) {
      this.http.get<any[]>(`${environment.apiUrl}/admin/empresas`).subscribe({
        next: rows => this.empresas.set(rows), error: () => {}
      });
    }

    switch (this.userRole) {
      case 1:
        this.rolNombre = 'Administrador';
        break;
      default:
        // El rol ya no controla los menús, pero podemos mostrar el nombre
        if (userRole) {
            const roles: Record<number, string> = {1: 'Admin', 2: 'Agente', 3: 'Propietario', 4: 'Cliente'};
            this.rolNombre = user.nombre || 'Perfil';
        }
        break;
    }
  }

  toggleHelp() {
    this.showHelp = !this.showHelp;
  }

  cambiarEmpresa() {
    this.authService.selectTenant(this.selectedTenant);
    // Reinicia los formularios y cachés de la empresa anterior, conservando la cola offline.
    window.location.reload();
  }

  logout() {
    this.authService.logout();
  }
}
