import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/services/auth.service';
import { environment } from '../../../../environments/environment';

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  selector: 'app-contratos',
  templateUrl: './contratos.html',
})
export class Contratos implements OnInit {
  private apiBase = environment.apiUrl;

  contratos: any[] = [];
  clientes: any[] = [];
  propiedades: any[] = [];
  filtroEstado: string = '';

  mensajeError: string = '';
  mensajeExito: string = '';

  mostrarFormulario: boolean = false;
  contratoForm: FormGroup;
  mostrarDetalle: boolean = false;
  contratoDetalle: any = null;
  pagoForm: FormGroup;
  enviandoPago: boolean = false;
  subiendoContrato: boolean = false;

  // Asistente IA (Módulo 7)
  chatAbierto: boolean = false;
  chatMensajes: { autor: string; texto: string }[] = [];
  chatInput: string = '';
  enviandoChat: boolean = false;

  constructor(
    private http: HttpClient,
    private fb: FormBuilder,
    private authService: AuthService,
    private cdr: ChangeDetectorRef,
  ) {
    this.contratoForm = this.fb.group({
      id_cliente: ['', Validators.required],
      id_propiedad: ['', Validators.required],
      tipo_contrato: ['Venta', Validators.required],
      monto_total: ['', [Validators.required, Validators.min(1)]],
      fecha_inicio: ['', Validators.required],
      fecha_fin: [''],
      num_cuotas: [''],
    });
    this.pagoForm = this.fb.group({
      monto: ['', [Validators.required, Validators.min(1)]],
      metodo_pago: ['Transferencia', Validators.required],
    });
  }

  ngOnInit() {
    this.loadContratos();
    this.loadClientes();
    this.loadPropiedades();
  }

  getHeaders() {
    const token = localStorage.getItem('token');
    let headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    const user = this.authService.currentUser();
    if (user && user.id_tenant) {
      headers = headers.set('X-Tenant-ID', user.id_tenant.toString());
    }
    return headers;
  }

  alerta(e: string, ok: boolean) {
    if (ok) {
      this.mensajeExito = e;
      this.mensajeError = '';
    } else {
      this.mensajeError = e;
      this.mensajeExito = '';
    }
    this.cdr.detectChanges();
    setTimeout(() => {
      if (ok) this.mensajeExito = '';
      else this.mensajeError = '';
      this.cdr.detectChanges();
    }, 4000);
  }

  loadContratos() {
    this.http.get(`${this.apiBase}/gestion_contractual/contratos`, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.contratos = [...res];
          this.cdr.detectChanges();
        },
        error: (err) => this.alerta(err.error?.detail || 'Error al cargar contratos.', false),
      });
  }

  filtrarContratos() {
    if (!this.filtroEstado) return this.contratos;
    return this.contratos.filter((c) => c.estado === this.filtroEstado);
  }

  loadClientes() {
    this.http.get(`${this.apiBase}/modulo_inmuebles/clientes`, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.clientes = res || [];
          this.cdr.detectChanges();
        },
        error: () => {},
      });
  }

  loadPropiedades() {
    this.http.get(`${this.apiBase}/modulo_inmuebles/propiedades`, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.propiedades = (res || []).filter((p: any) => ['Disponible', 'Reservada'].includes(p.estado));
          this.cdr.detectChanges();
        },
        error: () => {},
      });
  }

  abrirFormulario() {
    this.mostrarFormulario = true;
    this.mensajeError = '';
    this.mensajeExito = '';
  }

  cerrarFormulario() {
    this.mostrarFormulario = false;
    this.contratoForm.reset({ tipo_contrato: 'Venta' });
  }

  nombreCliente(id: number) {
    const c = this.clientes.find((x) => x.id_cliente === id);
    return c ? (c.nombre || c.ci_usuario || `#${id}`) : `Cliente #${id}`;
  }

  tituloPropiedad(id: number) {
    const p = this.propiedades.find((x) => x.id_propiedad === id);
    return p ? p.titulo : `Propiedad #${id}`;
  }

  tipoOperacionPropiedad(id: number) {
    const p = this.propiedades.find((x) => x.id_propiedad === id);
    return p && p.tipo_operacion;
  }

  onPropiedadSeleccionada(id: any) {
    const idNum = Number(id);
    this.contratoForm.patchValue({ id_propiedad: idNum });
    this.contratoForm.patchValue({ tipo_contrato: this.tipoOperacionPropiedad(idNum) || this.contratoForm.value.tipo_contrato });
  }

  crearContrato() {
    if (this.contratoForm.invalid) {
      this.alerta('Complete todos los campos requeridos del contrato.', false);
      return;
    }
    this.subiendoContrato = true;
    const payload = { ...this.contratoForm.value };
    if (!payload.fecha_fin) delete payload.fecha_fin;
    if (!payload.num_cuotas) delete payload.num_cuotas;

    this.http.post(`${this.apiBase}/gestion_contractual/contratos`, payload, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.subiendoContrato = false;
          this.cerrarFormulario();
          this.alerta(`Contrato #${res.id_contrato} creado con ${res.cuotas_totales} cuota(s).`, true);
          this.loadContratos();
          this.loadPropiedades();
        },
        error: (err) => {
          this.subiendoContrato = false;
          this.alerta(err.error?.detail || 'Error al crear el contrato.', false);
        },
      });
  }

  verDetalle(contrato: any) {
    this.http.get(`${this.apiBase}/gestion_contractual/contratos/${contrato.id_contrato}`, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.contratoDetalle = res;
          this.mostrarDetalle = true;
          this.pagoForm.reset({ metodo_pago: 'Transferencia' });
          this.cdr.detectChanges();
        },
        error: (err) => this.alerta(err.error?.detail || 'Error al abrir contrato.', false),
      });
  }

  cerrarDetalle() {
    this.mostrarDetalle = false;
    this.contratoDetalle = null;
  }

  registrarPago() {
    if (this.pagoForm.invalid || !this.contratoDetalle) return;
    this.enviandoPago = true;
    this.http.post(
      `${this.apiBase}/gestion_contractual/contratos/${this.contratoDetalle.id_contrato}/pagos`,
      this.pagoForm.value,
      { headers: this.getHeaders() },
    ).subscribe({
      next: (res: any) => {
        this.enviandoPago = false;
        this.alerta(`Pago registrado. Recibo ${res.numero_recibo}.`, true);
        this.verDetalle(this.contratoDetalle);
        this.loadContratos();
        this.loadPropiedades();
      },
      error: (err) => {
        this.enviandoPago = false;
        this.alerta(err.error?.detail || 'Error al registrar el pago.', false);
      },
    });
  }

  verComprobante(idPago: number) {
    this.http.get(`${this.apiBase}/gestion_contractual/pagos/${idPago}/comprobante`, {
      headers: this.getHeaders(),
      responseType: 'blob',
    }).subscribe({
      next: (blob: Blob) => {
        const url = URL.createObjectURL(blob);
        window.open(url, '_blank');
        setTimeout(() => URL.revokeObjectURL(url), 30000);
      },
      error: (err) => this.alerta('No se pudo abrir el comprobante.', false),
    });
  }

  eliminarContrato(contrato: any) {
    if (!confirm(`¿Eliminar el contrato #${contrato.id_contrato}? Esta acción no se puede revertir.`)) return;
    this.http.delete(`${this.apiBase}/gestion_contractual/contratos/${contrato.id_contrato}`, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.alerta('Contrato eliminado.', true);
          this.loadContratos();
        },
        error: (err) => this.alerta(err.error?.detail || 'Error al eliminar contrato.', false),
      });
  }

  // ---- Asistente IA (Rai) ----
  toggleChat() {
    this.chatAbierto = !this.chatAbierto;
    if (this.chatAbierto && this.chatMensajes.length === 0) {
      this.chatMensajes.push({ autor: 'ia', texto: 'Hola, soy Rai, el asistente virtual de Raíces. ¿En qué puedo ayudarte?' });
    }
  }

  enviarChat() {
    const texto = this.chatInput.trim();
    if (!texto || this.enviandoChat) return;
    this.chatMensajes.push({ autor: 'usuario', texto });
    this.chatInput = '';
    this.enviandoChat = true;
    this.http.post(`${this.apiBase}/api/ia/chat`, { mensaje: texto }, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.enviandoChat = false;
          this.chatMensajes.push({ autor: 'ia', texto: res.respuesta || 'Sin respuesta.' });
          this.cdr.detectChanges();
        },
        error: () => {
          this.enviandoChat = false;
          this.chatMensajes.push({ autor: 'ia', texto: 'Perdón, no pude responder en este momento.' });
          this.cdr.detectChanges();
        },
      });
  }
  
  esSuperAdmin(): boolean {
    const u = this.authService.currentUser();
    return !!u && (u.id_rol === 1);
  }
}
