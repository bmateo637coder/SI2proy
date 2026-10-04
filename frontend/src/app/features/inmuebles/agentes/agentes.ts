import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';

import { RouterModule } from '@angular/router';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, RouterModule],
  selector: 'app-agentes',
  templateUrl: './agentes.html',
})
export class Agentes implements OnInit {
  agentes: any[] = [];
  empresas: any[] = [];
  agenteForm: FormGroup;
  mensajeError: string = '';
  mensajeExito: string = '';
  
  userRole: number = 0;
  empresaSeleccionada: number | null = null;
  
  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef) {
    this.agenteForm = this.fb.group({
      ci_usuario: ['', Validators.required]
    });
  }

  ngOnInit() {
    const roleStr = localStorage.getItem('user_role');
    this.userRole = roleStr ? parseInt(roleStr, 10) : 0;

    if (this.userRole === 1) {
      this.loadEmpresas();
    } else {
      this.loadAgentes();
    }
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  loadEmpresas() {
    this.http.get<any[]>('http://localhost:8000/admin/empresas', { headers: this.getHeaders() })
      .subscribe({ next: (res) => { this.empresas = [...res]; this.cdr.detectChanges(); } });
  }

  onEmpresaChange() {
    if (this.empresaSeleccionada) {
      this.loadAgentes();
    } else {
      this.agentes = [];
    }
    this.cdr.detectChanges();
  }

  loadAgentes() {
    let url = 'http://localhost:8000/modulo_inmuebles/agentes';
    if (this.userRole === 1 && this.empresaSeleccionada) {
      url += `?id_tenant=${this.empresaSeleccionada}`;
    }
    this.http.get(url, { headers: this.getHeaders() })
      .subscribe((res: any) => {
        this.agentes = res;
        this.cdr.detectChanges();
      });
  }

  onSubmit() {
    if (this.agenteForm.valid) {
      this.mensajeError = '';
      this.mensajeExito = '';
      
      let payload = this.agenteForm.value;
      if (this.userRole === 1 && this.empresaSeleccionada) {
        payload = { ...payload, id_tenant: this.empresaSeleccionada };
      }

      this.http.post('http://localhost:8000/modulo_inmuebles/agentes', payload, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadAgentes();
            this.agenteForm.reset();
            this.mensajeExito = 'Agente registrado exitosamente.';
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

  deleteAgente(id: number) {
      this.http.delete(`http://localhost:8000/modulo_inmuebles/agentes/${id}`, { headers: this.getHeaders() })
        .subscribe(() => this.loadAgentes());
  }
}
