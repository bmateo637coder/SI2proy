import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';

import { RouterModule } from '@angular/router';
import { environment } from '../../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  selector: 'app-clientes',
  templateUrl: './clientes.html',
})
export class Clientes implements OnInit {
  clientes: any[] = [];
  clienteForm: FormGroup;
  mensajeError: string = '';
  mensajeExito: string = '';
  
  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef) {
    this.clienteForm = this.fb.group({
      ci_usuario: ['', Validators.required]
    });
  }

  ngOnInit() {
    this.loadClientes();
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  loadClientes() {
    this.http.get(`${environment.apiUrl}/modulo_inmuebles/clientes`, { headers: this.getHeaders() })
      .subscribe((res: any) => {
        this.clientes = res;
        this.cdr.detectChanges();
      });
  }

  onSubmit() {
    if (this.clienteForm.valid) {
      this.mensajeError = '';
      this.mensajeExito = '';
      this.http.post(`${environment.apiUrl}/modulo_inmuebles/clientes`, this.clienteForm.value, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadClientes();
            this.clienteForm.reset();
            this.mensajeExito = 'Cliente registrado exitosamente.';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          },
          error: (err) => {
            console.error(err);
            this.mensajeError = err.error?.detail || 'Error al registrar. Verifique que el CI exista en Usuarios y no esté duplicado.';
            this.cdr.detectChanges();
          }
        });
    }
  }

  deleteCliente(id: number) {
      this.http.delete(`${environment.apiUrl}/modulo_inmuebles/clientes/${id}`, { headers: this.getHeaders() })
        .subscribe(() => this.loadClientes());
  }
}
