import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { environment } from '../../../../environments/environment';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  selector: 'app-propiedades',
  templateUrl: './propiedades.html',
})
export class Propiedades implements OnInit {
  propiedades: any[] = [];
  propietarios: any[] = [];
  agentes: any[] = [];
  empresas: any[] = [];

  propiedadForm: FormGroup;
  editForm: FormGroup;

  mensajeError: string = '';
  mensajeExito: string = '';
  userRole: number = 0;

  // Super Admin: empresa seleccionada para filtrar
  empresaSeleccionada: number | null = null;
  get canManage() { return this.userRole === 2 || (this.userRole === 1 && !!this.empresaSeleccionada); }

  // Modal de edición
  mostrarModalEditar: boolean = false;
  propiedadEditando: any = null;

  // Modal crear
  mostrarModalCrear: boolean = false;

  constructor(private http: HttpClient, private fb: FormBuilder, private cdr: ChangeDetectorRef, public auth: AuthService) {
    const formDef = {
      id_propietario: ['', Validators.required],
      id_agente: ['', Validators.required],
      titulo: ['', Validators.required],
      direccion: ['', Validators.required],
      precio: ['', [Validators.required, Validators.min(1)]],
      tipo_operacion: ['Venta', Validators.required],
      descripcion: [''],
      imagen_url: [''],
      superficie: ['', [Validators.min(1)]],
      habitaciones: ['', [Validators.min(1), Validators.pattern(/^[0-9]+$/)]],
      zona: ['']
    };
    this.propiedadForm = this.fb.group(formDef);
    this.editForm = this.fb.group(formDef);
  }

  ngOnInit() {
    const roleStr = localStorage.getItem('user_role');
    this.userRole = roleStr ? parseInt(roleStr, 10) : 0;

    if (this.userRole === 1) {
      this.empresaSeleccionada = this.auth.tenantId();
      this.loadEmpresas();
      if (this.empresaSeleccionada || this.auth.allTenants()) this.onEmpresaChange(false);
    } else {
      this.loadPropiedades();
      this.loadPropietarios();
      this.loadAgentes();
    }
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  // ── Super Admin: cargar empresas para selector ──
  loadEmpresas() {
    this.http.get<any[]>(`${environment.apiUrl}/admin/empresas`, { headers: this.getHeaders() })
      .subscribe({ next: (res) => { this.empresas = [...res]; this.cdr.detectChanges(); } });
  }

  onEmpresaChange(persist = true) {
    if (persist) {
      this.auth.selectTenant(this.empresaSeleccionada);
      window.location.reload();
      return;
    }
    if (this.empresaSeleccionada || this.auth.allTenants()) {
      this.loadPropiedades();
      this.loadPropietarios();
      this.loadAgentes();
    } else {
      this.propiedades = [];
    }
    this.cdr.detectChanges();
  }

  // ── Cargar datos ──
  loadPropiedades() {
    let url = `${environment.apiUrl}/modulo_inmuebles/propiedades`;
    if (this.userRole === 1 && this.empresaSeleccionada) {
      url += `?id_tenant=${this.empresaSeleccionada}`;
    }
    this.http.get<any[]>(url, { headers: this.getHeaders() })
      .subscribe({
        next: (res) => { this.propiedades = [...res]; this.cdr.detectChanges(); },
        error: (err) => { console.error('Error propiedades:', err); }
      });
  }

  loadPropietarios() {
    let url = `${environment.apiUrl}/modulo_inmuebles/propietarios`;
    if (this.userRole === 1 && this.empresaSeleccionada) {
      url += `?id_tenant=${this.empresaSeleccionada}`;
    }
    this.http.get<any[]>(url, { headers: this.getHeaders() })
      .subscribe({ next: (res) => { this.propietarios = [...res]; this.cdr.detectChanges(); } });
  }

  loadAgentes() {
    let url = `${environment.apiUrl}/modulo_inmuebles/agentes`;
    if (this.userRole === 1 && this.empresaSeleccionada) {
      url += `?id_tenant=${this.empresaSeleccionada}`;
    }
    this.http.get<any[]>(url, { headers: this.getHeaders() })
      .subscribe({ next: (res) => { this.agentes = [...res]; this.cdr.detectChanges(); } });
  }

  // ── Crear propiedad ──
  abrirModalCrear() {
    this.propiedadForm.reset({ tipo_operacion: 'Venta' });
    this.mensajeError = '';
    this.mostrarModalCrear = true;
  }

  onSubmit() {
    if (this.propiedadForm.valid) {
      this.mensajeError = '';
      const formData = {
        ...this.propiedadForm.value,
        caracteristicas: this.caracteristicas(this.propiedadForm),
        id_propietario: parseInt(this.propiedadForm.value.id_propietario, 10),
        id_agente: parseInt(this.propiedadForm.value.id_agente, 10),
        precio: parseFloat(this.propiedadForm.value.precio),
        imagenes: this.propiedadForm.value.imagen_url ? [this.propiedadForm.value.imagen_url] : []
      };
      this.http.post(`${environment.apiUrl}/modulo_inmuebles/propiedades`, formData, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadPropiedades();
            this.mostrarModalCrear = false;
            this.mensajeExito = '¡Propiedad creada exitosamente!';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          },
          error: (err) => {
            this.mensajeError = err.error?.detail || 'Error al crear propiedad.';
            this.cdr.detectChanges();
          }
        });
    }
  }

  subiendoImagen = false;
  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.subiendoImagen = true;
      this.cdr.detectChanges();
      const fd = new FormData();
      fd.append('file', file);
      this.http.post(`${environment.apiUrl}/upload`, fd).subscribe({
        next: (res: any) => {
          this.propiedadForm.patchValue({ imagen_url: res.url });
          this.subiendoImagen = false;
          this.cdr.detectChanges();
        },
        error: (err) => {
          console.error(err);
          this.subiendoImagen = false;
          alert('Error al subir imagen');
          this.cdr.detectChanges();
        }
      });
    }
  }

  generandoDescripcion = false;

  generarDescripcionIA() {
    const f = this.propiedadForm.value;
    if (!f.titulo || !f.direccion || !f.precio || !f.tipo_operacion) {
      alert("Por favor, llena el título, dirección, precio y tipo de operación para que la IA pueda generar la descripción.");
      return;
    }

    this.generandoDescripcion = true;
    this.cdr.detectChanges();

    const payload = {
      titulo: f.titulo,
      direccion: f.direccion,
      precio: f.precio,
      tipo_operacion: f.tipo_operacion
    };

    this.http.post(`${environment.apiUrl}/api/ia/generar-descripcion`, payload, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.generandoDescripcion = false;
          if (res.success && res.descripcion) {
            this.propiedadForm.patchValue({ descripcion: res.descripcion });
          }
          this.cdr.detectChanges();
        },
        error: (err) => {
          this.generandoDescripcion = false;
          console.error(err);
          this.mensajeError = err.error?.detail || 'No se pudo generar la descripción.';
          this.cdr.detectChanges();
        }
      });
  }

  // ── Editar propiedad ──
  abrirEditar(prop: any) {
    this.propiedadEditando = prop;
    this.editForm.patchValue({
      id_propietario: prop.id_propietario,
      id_agente: prop.id_agente,
      titulo: prop.titulo,
      direccion: prop.direccion,
      precio: prop.precio,
      tipo_operacion: prop.tipo_operacion,
      descripcion: prop.descripcion || '',
      imagen_url: prop.imagenes?.[0]?.url || '',
      superficie: this.atributo(prop, ['superficie', 'metros cuadrados', 'm2', 'area', 'metros_cuadrados']),
      habitaciones: this.atributo(prop, ['habitaciones', 'cuartos', 'dormitorios']),
      zona: this.atributo(prop, ['zona'])
    });
    this.mensajeError = '';
    this.mostrarModalEditar = true;
    this.cdr.detectChanges();
  }

  onEditSubmit() {
    if (this.editForm.valid && this.propiedadEditando) {
      const formData = {
        ...this.editForm.value,
        caracteristicas: this.caracteristicas(this.editForm),
        imagenes: [this.editForm.value.imagen_url, ...(this.propiedadEditando.imagenes || []).slice(1).map((img: any) => img.url)].filter(Boolean),
        id_propietario: parseInt(this.editForm.value.id_propietario, 10),
        id_agente: parseInt(this.editForm.value.id_agente, 10),
        precio: parseFloat(this.editForm.value.precio)
      };
      this.http.put(`${environment.apiUrl}/modulo_inmuebles/propiedades/${this.propiedadEditando.id_propiedad}`, formData, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadPropiedades();
            this.mostrarModalEditar = false;
            this.mensajeExito = '¡Propiedad actualizada exitosamente!';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          },
          error: (err) => {
            this.mensajeError = err.error?.detail || 'Error al modificar propiedad.';
            this.cdr.detectChanges();
          }
        });
    }
  }

  // ── Cambiar estado ──
  private normalizar(value: string): string {
    return value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  }
  private atributo(prop: any, names: string[]): string {
    return prop.caracteristicas?.find((c: any) => names.includes(this.normalizar(c.nombre)))?.valor || '';
  }
  private caracteristicas(form: FormGroup) {
    const fields = [['superficie', ['superficie', 'metros cuadrados', 'm2', 'area', 'metros_cuadrados']],
      ['habitaciones', ['habitaciones', 'cuartos', 'dormitorios']], ['zona', ['zona']]] as const;
    return fields.map(([field, names]) => {
      const old = this.propiedadEditando?.caracteristicas?.find((c: any) => (names as readonly string[]).includes(this.normalizar(c.nombre)));
      return { nombre: form === this.editForm && old ? old.nombre : field === 'superficie' ? 'Superficie' : field === 'habitaciones' ? 'Habitaciones' : 'Zona', valor: String(form.value[field] || '') };
    });
  }

  updateEstado(id: number, estado: string) {
    this.http.put(`${environment.apiUrl}/modulo_inmuebles/propiedades/${id}/estado`, { estado }, { headers: this.getHeaders() })
      .subscribe({ next: () => this.loadPropiedades() });
  }

  // ── Eliminar propiedad ──
  deletePropied(id: number) {
    if (confirm('¿Desea eliminar esta propiedad? Esta acción no se puede deshacer.')) {
      this.http.delete(`${environment.apiUrl}/modulo_inmuebles/propiedades/${id}`, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadPropiedades();
            this.mensajeExito = 'Propiedad eliminada.';
            this.cdr.detectChanges();
            setTimeout(() => { this.mensajeExito = ''; this.cdr.detectChanges(); }, 3000);
          }
        });
    }
  }

  getEstadoColor(estado: string): string {
    switch(estado) {
      case 'Disponible': return '#22c55e';
      case 'Reservada': return '#eab308';
      case 'Vendida': return '#ef4444';
      case 'Alquilada': return '#3b82f6';
      default: return '#94a3b8';
    }
  }

  getEstadoBg(estado: string): string {
    switch(estado) {
      case 'Disponible': return '#dcfce7';
      case 'Reservada': return '#fef9c3';
      case 'Vendida': return '#fee2e2';
      case 'Alquilada': return '#dbeafe';
      default: return '#f1f5f9';
    }
  }
}
