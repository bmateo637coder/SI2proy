import { Component } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';
import { HasPermissionDirective } from '../../core/directives/has-permission.directive';
import { AuthService } from '../../core/services/auth.service';
import { environment } from '../../../environments/environment';

@Component({
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, CommonModule, HasPermissionDirective],
  selector: 'app-layout',
  styleUrl: './layout.css',
  templateUrl: './layout.html',
})
export class Layout {
  userRole: number = 0;
  rolNombre: string = 'Inmobiliaria';
  tenantNombre: string = '';
  showHelp: boolean = false;
  buildVersion: string = environment.version;

  constructor(private router: Router, private authService: AuthService) {
    const userRole = localStorage.getItem('user_role');
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    this.userRole = userRole ? parseInt(userRole, 10) : 0;
    
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

  logout() {
    this.authService.logout();
  }
}
