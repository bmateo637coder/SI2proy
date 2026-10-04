import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  selector: 'app-roles',
  styleUrl: './roles.css',
  templateUrl: './roles.html',
})
export class Roles implements OnInit {
  roles: any[] = [];
  permisos: any[] = [];
  selectedRole: any = null;
  rolForm: FormGroup;
  mensaje: string = '';
  error: boolean = false;

  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef) {
    this.rolForm = this.fb.group({
      nombre: ['', [Validators.required, Validators.minLength(3)]]
    });
  }

  userRole: number = 0;
  empresas: any[] = [];
  groupedRoles: { [key: string]: any[] } = {};
  groupedKeys: string[] = [];

  ngOnInit() {
    const userRoleStr = localStorage.getItem('user_role');
    this.userRole = userRoleStr ? parseInt(userRoleStr, 10) : 0;
    
    if (this.userRole === 1) {
        this.loadEmpresas();
    } else {
        this.cargarRoles();
    }
    this.cargarPermisos();
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  loadEmpresas() {
      this.http.get('http://localhost:8000/admin/empresas', { headers: this.getHeaders() })
      .subscribe((res: any) => {
          this.empresas = res;
          this.cargarRoles();
      });
  }

  cargarPermisos() {
    this.http.get('http://localhost:8000/permisos', { headers: this.getHeaders() }).subscribe({
      next: (data: any) => {
        this.permisos = data;
        this.cdr.detectChanges();
      },
      error: (err) => console.error(err)
    });
  }

  cargarRoles() {
    this.http.get('http://localhost:8000/roles', { headers: this.getHeaders() }).subscribe({
      next: (data: any) => {
        this.roles = data;
        this.groupRoles();
        this.cdr.detectChanges();
      },
      error: (err) => console.error(err)
    });
  }

  groupRoles() {
      this.groupedRoles = {};
      
      this.roles.forEach(rol => {
          let companyName = 'Roles Globales (Sistema)';
          if (rol.id_tenant) {
              if (this.userRole === 1) {
                  const emp = this.empresas.find(e => e.id_tenant === rol.id_tenant);
                  companyName = emp ? emp.nombre : `Empresa ID: ${rol.id_tenant}`;
              } else {
                  companyName = 'Roles de Mi Empresa';
              }
          }
          if (!this.groupedRoles[companyName]) {
              this.groupedRoles[companyName] = [];
          }
          this.groupedRoles[companyName].push(rol);
      });
      
      this.groupedKeys = Object.keys(this.groupedRoles);
  }

  seleccionarRol(rol: any) {
    this.selectedRole = rol;
    
    // Asignar los permisos del rol al estado de los checkboxes
    // Como el GET /roles actual no devuelve los permisos detallados, 
    // asumiremos que el rol tiene un array `permisos` si se lo inyectamos desde el backend
    // Si no, lo iniciamos vacío
    if (!this.selectedRole.permisos) {
      this.selectedRole.permisos = [];
    }
    
    this.cdr.detectChanges();
  }

  togglePermiso(permisoId: number, event: any) {
    const checked = event.target.checked;
    let permisosIds = this.selectedRole.permisos.map((p: any) => p.id_permiso || p);
    
    if (checked) {
      permisosIds.push(permisoId);
    } else {
      permisosIds = permisosIds.filter((id: number) => id !== permisoId);
    }

    const token = localStorage.getItem('token');
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    
    this.http.put(`http://localhost:8000/roles/${this.selectedRole.id_rol}/permisos`, permisosIds, { headers }).subscribe({
      next: (res) => {
        this.selectedRole.permisos = permisosIds; // Optimistic update
        this.cdr.detectChanges();
      },
      error: (err) => console.error(err)
    });
  }

  agregarRol() {
    if (this.rolForm.valid) {
      const token = localStorage.getItem('token');
      const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
      
      this.http.post('http://localhost:8000/roles', this.rolForm.value, { headers }).subscribe({
        next: (nuevoRol: any) => {
          this.roles.push(nuevoRol);
          this.rolForm.reset();
          this.mensaje = '¡Rol agregado exitosamente!';
          this.error = false;
          this.cdr.detectChanges(); // Forzar actualización de la UI
          
          setTimeout(() => {
            this.mensaje = '';
            this.cdr.detectChanges();
          }, 3000);
        },
        error: (err) => {
          this.mensaje = 'Error al agregar el rol (es posible que ya exista).';
          this.error = true;
          this.cdr.detectChanges();
        }
      });
    }
  }
}
