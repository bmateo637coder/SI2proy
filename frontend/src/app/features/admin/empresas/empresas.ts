import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { environment } from '../../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  selector: 'app-empresas',
  templateUrl: './empresas.html',
})
export class Empresas implements OnInit {
  empresas: any[] = [];
  empresaForm: FormGroup;
  mensajeError: string = '';
  mensajeExito: string = '';
  mostrarModal: boolean = false;

  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef) {
    this.empresaForm = this.fb.group({
      nombre: ['', Validators.required],
      dominio: [''],
      admin_ci: ['', Validators.required],
      admin_nombre: ['', Validators.required],
      admin_correo: ['', [Validators.required, Validators.email]],
      admin_telefono: ['']
    });
  }

  ngOnInit() {
    this.loadEmpresas();
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  loadEmpresas() {
    this.http.get<any[]>(`${environment.apiUrl}/admin/empresas`, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any[]) => {
          this.empresas = [...res];
          console.log('Empresas cargadas:', this.empresas.length);
          this.cdr.detectChanges();
        },
        error: (err) => {
          console.error('Error cargando empresas:', err);
          this.mensajeError = err.error?.detail || `Error ${err.status}: No se pudieron cargar las empresas.`;
          this.cdr.detectChanges();
        }
      });
  }

  onSubmit() {
    if (this.empresaForm.valid) {
      this.http.post(`${environment.apiUrl}/admin/empresas`, this.empresaForm.value, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadEmpresas();
            this.mostrarModal = false;
            this.empresaForm.reset();
            this.mensajeExito = 'Empresa y administrador creados exitosamente.';
            setTimeout(() => this.mensajeExito = '', 3000);
          },
          error: (err) => {
            this.mensajeError = err.error?.detail || 'Error al crear la empresa.';
          }
        });
    }
  }
  
  resetPassword(idEmpresa: number) {
      if (confirm('¿Está seguro de que desea restablecer la contraseña del administrador a "12345"?')) {
          this.http.put(`${environment.apiUrl}/admin/empresas/${idEmpresa}/reset-admin-password`, {}, { headers: this.getHeaders() })
            .subscribe({
                next: (res: any) => {
                    alert(res.message);
                },
                error: (err) => {
                    alert(err.error?.detail || 'Error al restablecer la contraseña.');
                }
            });
      }
  }
}
