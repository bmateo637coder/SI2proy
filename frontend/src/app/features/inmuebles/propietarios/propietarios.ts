import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, RouterModule],
  selector: 'app-propietarios',
  templateUrl: './propietarios.html',
})
export class Propietarios implements OnInit {
  propietarios: any[] = [];
  empresas: any[] = [];

  propietarioForm: FormGroup;
  editForm: FormGroup;

  mensajeError: string = '';
  mensajeExito: string = '';

  userRole: number = 0;

  // SuperAdmin: empresa seleccionada
  empresaSeleccionada: number | null = null;

  // Modales
  mostrarModalCrear: boolean = false;
  mostrarModalEditar: boolean = false;
  propietarioEditando: any = null;

  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef) {
    this.propietarioForm = this.fb.group({
      ci_usuario: ['', Validators.required]
    });
    this.editForm = this.fb.group({
      ci_usuario: ['', Validators.required]
    });
  }

  ngOnInit() {
    const roleStr = localStorage.getItem('user_role');
    this.userRole = roleStr ? parseInt(roleStr, 10) : 0;

    if (this.userRole === 1) {
      this.loadEmpresas();
    } else {
      this.loadPropietarios();
    }
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  // ── SuperAdmin: cargar empresas ──
  loadEmpresas() {
    this.http.get<any[]>('http://localhost:8000/admin/empresas', { headers: this.getHeaders() })
      .subscribe({ next: (res) => { this.empresas = [...res]; this.cdr.detectChanges(); } });
  }

  onEmpresaChange() {
    if (this.empresaSeleccionada) {
      this.loadPropietarios();
    } else {
      this.propietarios = [];
    }
    this.cdr.detectChanges();
  }

  // ── Cargar propietarios ──
  loadPropietarios() {
    let url = 'http://localhost:8000/modulo_inmuebles/propietarios';
    if (this.userRole === 1 && this.empresaSeleccionada) {
      url += `?id_tenant=${this.empresaSeleccionada}`;
    }
    this.http.get<any[]>(url, { headers: this.getHeaders() })
      .subscribe({
        next: (res) => { this.propietarios = [...res]; this.cdr.detectChanges(); },
        error: (err) => { console.error('Error propietarios:', err); }
      });
  }

  // ── Modal Crear ──
  abrirModalCrear() {
    this.propietarioForm.reset();
    this.mensajeError = '';
    this.mostrarModalCrear = true;
  }

  onSubmit() {
    if (this.propietarioForm.valid) {
      this.mensajeError = '';
      this.http.post('http://localhost:8000/modulo_inmuebles/propietarios', this.propietarioForm.value, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadPropietarios();
            this.mostrarModalCrear = false;
            this.propietarioForm.reset();
            this.mensajeExito = '¡Propietario registrado exitosamente!';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          },
          error: (err) => {
            this.mensajeError = err.error?.detail || 'Error al registrar. Verifique que el CI exista en Usuarios y no esté duplicado.';
            this.cdr.detectChanges();
          }
        });
    }
  }

  // ── Modal Editar ──
  abrirEditar(propietario: any) {
    this.propietarioEditando = propietario;
    this.editForm.patchValue({ ci_usuario: propietario.ci_usuario });
    this.mensajeError = '';
    this.mostrarModalEditar = true;
    this.cdr.detectChanges();
  }

  onEditSubmit() {
    if (this.editForm.valid && this.propietarioEditando) {
      this.mensajeError = '';
      this.http.put(
        `http://localhost:8000/modulo_inmuebles/propietarios/${this.propietarioEditando.id_propietario}`,
        this.editForm.value,
        { headers: this.getHeaders() }
      ).subscribe({
        next: () => {
          this.loadPropietarios();
          this.mostrarModalEditar = false;
          this.mensajeExito = '¡Propietario actualizado exitosamente!';
          this.cdr.detectChanges();
          setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
        },
        error: (err) => {
          this.mensajeError = err.error?.detail || 'Error al actualizar. Verifique que el CI exista.';
          this.cdr.detectChanges();
        }
      });
    }
  }

  // ── Eliminar ──
  deletePropietario(id: number) {
    if (confirm('¿Desea eliminar este propietario? Esta acción no se puede deshacer.')) {
      this.http.delete(`http://localhost:8000/modulo_inmuebles/propietarios/${id}`, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadPropietarios();
            this.mensajeExito = 'Propietario eliminado.';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          }
        });
    }
  }
}
