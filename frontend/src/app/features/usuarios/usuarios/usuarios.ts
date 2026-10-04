import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  selector: 'app-usuarios',
  templateUrl: './usuarios.html',
})
export class Usuarios implements OnInit {
  usuarios: any[] = [];
  roles: any[] = [];
  usuarioForm: FormGroup;
  mensajeError: string = '';
  mensajeExito: string = '';
  
  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef) {
    this.usuarioForm = this.fb.group({
      ci: ['', Validators.required],
      nombre: ['', Validators.required],
      correo: ['', [Validators.required, Validators.email]],
      telefono: [''],
      password: ['', Validators.required],
      id_rol: ['', Validators.required]
    });
  }

  userRole: number = 0;
  empresas: any[] = [];
  groupedUsuarios: { [key: string]: any[] } = {};
  groupedKeys: string[] = [];

  ngOnInit() {
    const userRoleStr = localStorage.getItem('user_role');
    this.userRole = userRoleStr ? parseInt(userRoleStr, 10) : 0;
    
    if (this.userRole === 1) {
        this.loadEmpresas();
    } else {
        this.loadUsuarios();
    }
    this.loadRoles();
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }
  
  loadEmpresas() {
      this.http.get('http://localhost:8000/admin/empresas', { headers: this.getHeaders() })
      .subscribe((res: any) => {
          this.empresas = res;
          this.loadUsuarios();
      });
  }

  loadUsuarios() {
    this.http.get('http://localhost:8000/gestion_usuarios/usuarios', { headers: this.getHeaders() })
      .subscribe((res: any) => {
        this.usuarios = res;
        this.groupUsuarios();
        this.cdr.detectChanges();
      });
  }
  
  groupUsuarios() {
      this.groupedUsuarios = {};
      
      this.usuarios.forEach(user => {
          let companyName = 'Sin Empresa Asignada';
          if (user.id_tenant) {
              if (this.userRole === 1) {
                  const emp = this.empresas.find(e => e.id_tenant === user.id_tenant);
                  companyName = emp ? emp.nombre : `Empresa ID: ${user.id_tenant}`;
              } else {
                  companyName = 'Mi Empresa';
              }
          }
          if (!this.groupedUsuarios[companyName]) {
              this.groupedUsuarios[companyName] = [];
          }
          this.groupedUsuarios[companyName].push(user);
      });
      
      this.groupedKeys = Object.keys(this.groupedUsuarios);
  }

  loadRoles() {
    this.http.get('http://localhost:8000/gestion_usuarios/roles', { headers: this.getHeaders() })
      .subscribe((res: any) => {
        this.roles = res;
        this.cdr.detectChanges();
      });
  }

  getRoleName(id: number) {
    const role = this.roles.find(r => r.id_rol === id);
    return role ? role.nombre : 'Desconocido';
  }

  onSubmit() {
    if (this.usuarioForm.valid) {
      this.mensajeError = '';
      this.mensajeExito = '';
      
      const formData = {
        ...this.usuarioForm.value,
        id_rol: parseInt(this.usuarioForm.value.id_rol, 10)
      };
      
      this.http.post('http://localhost:8000/gestion_usuarios/usuarios', formData, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadUsuarios();
            this.usuarioForm.reset();
            this.mensajeExito = 'Usuario creado exitosamente.';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          },
          error: (err) => {
            console.error(err);
            this.mensajeError = err.error?.detail || 'Error al crear el usuario. Verifique los datos.';
            this.cdr.detectChanges();
          }
        });
    }
  }
}
