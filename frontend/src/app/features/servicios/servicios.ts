import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom, timeout } from 'rxjs';
import { API, errorTexto } from '../../core/services/api';
import { AuthService } from '../../core/services/auth.service';
import { PushService } from '../../core/services/push.service';

@Component({ standalone: true, imports: [CommonModule, FormsModule, RouterLink],
  styleUrl: '../parcial2.css', template: `
<main class="page">
 <h1>Servicios inmobiliarios</h1>
 <nav class="actions"><a routerLink="/dashboard/favoritos">Favoritos y alertas</a> ·
  <a routerLink="/dashboard/notificaciones">Notificaciones</a> · <a routerLink="/dashboard/mantenimiento">Mantenimiento</a>
  <ng-container *ngIf="staff"> · <a routerLink="/dashboard/gerencia">Dashboard gerencial</a> ·
   <a routerLink="/dashboard/mapa-calor">Mapa de ventas</a> · <a routerLink="/dashboard/comisiones">Comisiones</a> ·
   <a routerLink="/dashboard/promociones">Promociones</a> · <a routerLink="/dashboard/plan">Suscripción</a></ng-container>
 </nav>
 <p role="status" aria-live="polite">{{message()}}</p>
 <section class="card"><h2>Buscar con lenguaje natural</h2>
  <form (ngSubmit)="buscar()"><input class="modern-input" name="busqueda" [(ngModel)]="texto" aria-label="Búsqueda natural" placeholder="Casa en venta con 3 habitaciones hasta 150 mil" required>
   <button class="btn-primary" [disabled]="busy()">Buscar</button></form>
  <p>{{resumen()}}</p>
  <div *ngFor="let p of resultados()" class="card"><h3>{{p.titulo}}</h3><p>{{p.direccion}} · {{p.precio | number:'1.2-2'}} · {{p.tipo_operacion}}</p>
   <button class="btn-secondary" (click)="favorito(p.id_propiedad)" [disabled]="busy()">Guardar favorito</button>
   <button class="btn-secondary" (click)="pid = p.id_propiedad">Seleccionar para IA</button></div>
 </section>
 <section class="card"><h2>Recomendaciones personalizadas</h2><button class="btn-secondary" (click)="recomendar()" [disabled]="busy()">Actualizar recomendaciones</button>
  <p *ngIf="!recomendados().length">Sin recomendaciones disponibles. Actualiza o guarda favoritos para indicar tus preferencias.</p>
  <div *ngFor="let r of recomendados()" class="card"><h3>{{r.propiedad.titulo}}</h3><p>{{r.propiedad.precio | number:'1.2-2'}} · {{r.motivos.join(', ')}}</p>
   <button class="btn-secondary" (click)="favorito(r.propiedad.id_propiedad)">Guardar favorito</button>
   <label>Valoración <select [(ngModel)]="r.valoracion"><option [ngValue]="1">1 - No me interesa</option><option [ngValue]="3">3 - Neutral</option><option [ngValue]="5">5 - Me interesa</option></select></label>
   <input class="modern-input" [(ngModel)]="r.comentario" aria-label="Comentario de recomendación" placeholder="Cuéntanos qué mejorar">
   <button class="btn-secondary" (click)="feedback(r)" [disabled]="busy()">Enviar feedback</button></div>
 </section>
 <section class="card"><h2>Asistente, descripción y cotización</h2>
  <label>Inmueble <select [(ngModel)]="pid" aria-label="Inmueble para IA"><option [ngValue]="null">Selecciona un inmueble</option><option *ngFor="let p of propiedades()" [ngValue]="p.id_propiedad">{{p.titulo}}</option></select></label>
  <textarea class="modern-input" [(ngModel)]="pregunta" aria-label="Pregunta al asistente" placeholder="Escribe tu consulta"></textarea>
  <button class="btn-primary" (click)="ia('chat')" [disabled]="busy()">Consultar asistente</button>
  <button class="btn-secondary" (click)="ia('cotizar')" [disabled]="busy() || !pid">Cotizar con IA</button>
  <button class="btn-secondary" (click)="ia('descripcion')" [disabled]="busy() || !pid">Generar descripción</button>
  <p *ngIf="respuesta()" style="white-space:pre-wrap">{{respuesta()}}</p><small>{{modo()}}</small>
 </section>
 <section class="card"><h2>Agendar visita</h2><p>Selecciona el inmueble en el formulario de IA.</p>
  <label>Fecha y hora <input type="datetime-local" [(ngModel)]="fechaVisita"></label>
  <label *ngIf="staff">Cliente <select [(ngModel)]="clienteVisita"><option [ngValue]="null">Selecciona un cliente</option><option *ngFor="let c of clientes()" [ngValue]="c.id_cliente">{{c.nombre}} · {{c.inmobiliaria}}</option></select></label>
  <button class="btn-primary" (click)="visita()" [disabled]="busy() || !pid || !fechaVisita">Agendar visita</button>
  <a routerLink="/dashboard/visitas">Consultar agenda</a></section>
 <section class="card"><h2>Mi estado de cuenta</h2><button class="btn-secondary" (click)="cuenta()" [disabled]="busy()">Consultar contratos y pagos</button>
  <div *ngIf="estadoCuenta() as c"><p>Pagado: {{c.pagado | number:'1.2-2'}} · Saldo: {{c.saldo | number:'1.2-2'}}</p>
   <article *ngFor="let contrato of c.contratos" class="card"><h3>{{contrato.propiedad}} · {{contrato.tipo_contrato}}</h3><p>{{contrato.estado}} · Saldo {{contrato.saldo_pendiente | number:'1.2-2'}}</p>
    <div *ngFor="let p of contrato.pagos"><span>{{p.numero_recibo}} · {{p.monto | number:'1.2-2'}}</span>
     <button class="btn-secondary" (click)="enviar(p.id_pago)" [disabled]="busy()">Enviar comprobante por Gmail</button></div>
    <p *ngIf="!contrato.pagos.length">Todavía no hay pagos registrados.</p>
    <ul><li *ngFor="let cuota of contrato.cuotas">Cuota {{cuota.numero_cuota}} · {{cuota.fecha_vencimiento}} · {{cuota.estado}} · {{cuota.monto}}</li></ul>
   </article><p *ngIf="!c.contratos.length">No tienes contratos en el alcance seleccionado.</p></div>
 </section>
 <section class="card"><h2>Notificaciones push</h2><button class="btn-primary" (click)="activarPush()" [disabled]="busy()">Activar en este navegador</button>
  <button class="btn-secondary" (click)="pruebaPush()" [disabled]="busy()">Enviar prueba</button></section>
 <section class="card" *ngIf="staff"><h2>Reporte ejecutivo consolidado</h2>
  <button class="btn-primary" (click)="exportar('pdf')" [disabled]="busy()">Descargar PDF ejecutivo</button>
  <button class="btn-secondary" (click)="exportar('csv')" [disabled]="busy()">Descargar CSV ejecutivo</button></section>
</main>` })
export class Servicios {
 private http = inject(HttpClient); readonly auth = inject(AuthService); private push = inject(PushService);
 readonly busy = signal(false); readonly message = signal(''); readonly resultados = signal<any[]>([]);
 readonly recomendados = signal<any[]>([]); readonly propiedades = signal<any[]>([]); readonly resumen = signal('');
 readonly respuesta = signal(''); readonly modo = signal(''); readonly estadoCuenta = signal<any>(null);
 texto = ''; pregunta = ''; pid: number | null = null;
 fechaVisita = ''; clienteVisita: number | null = null; readonly clientes = signal<any[]>([]);
 get staff() { return this.auth.currentUser()?.id_rol === 1 || this.auth.currentUser()?.id_rol === 2 || this.auth.currentUser()?.es_agente; }
 constructor() { void this.act(async () => { this.propiedades.set(await this.get('/modulo_inmuebles/propiedades/catalogo')); if(this.staff) this.clientes.set(await this.get('/modulo_inmuebles/clientes')); }); }
 private get(path: string) { return firstValueFrom(this.http.get<any>(API + path).pipe(timeout(90000))); }
 private post(path: string, data = {}) { return firstValueFrom(this.http.post<any>(API + path, data).pipe(timeout(90000))); }
 async act(fn: () => Promise<void>) { if (this.busy()) return; this.busy.set(true); this.message.set('');
  try { await fn(); } catch(e: any) { this.message.set(e.message && !e.status ? e.message : errorTexto(e, 'No se pudo completar la solicitud. Revisa la conexión.')); }
  finally { this.busy.set(false); } }
 buscar() { void this.act(async () => { const r = await this.post('/api/busqueda-semantica', {texto: this.texto}); this.resultados.set(r.resultados); this.resumen.set(r.resumen + ' · ' + r.modo); }); }
 recomendar() { void this.act(async () => { const r = await this.get('/api/recomendaciones'); this.recomendados.set(r.recomendaciones.map((x: any) => ({...x, valoracion: 3, comentario: ''}))); }); }
 favorito(id: number) { void this.act(async () => { await this.post('/api/favoritos/' + id); this.message.set('Inmueble guardado en favoritos.'); }); }
 feedback(r: any) { void this.act(async () => { await this.post('/api/recomendaciones/feedback', {id_propiedad: r.propiedad.id_propiedad, valoracion: r.valoracion, comentario: r.comentario}); this.message.set('Feedback guardado. Se aplicará a tus próximas recomendaciones.'); }); }
 ia(accion: string) { void this.act(async () => { const r = await this.post('/api/servicios/ia/' + accion, {id_propiedad: this.pid, texto: this.pregunta}); this.respuesta.set(r.respuesta); this.modo.set(r.modo + (r.advertencia ? ' · ' + r.advertencia : '')); }); }
 cuenta() { void this.act(async () => { this.estadoCuenta.set(await this.get('/api/mi-cuenta')); }); }
 enviar(id: number) { void this.act(async () => { const r = await this.post('/api/pagos/' + id + '/enviar-recibo'); this.message.set('Comprobante enviado a ' + r.destinatario); }); }
 visita() { void this.act(async () => { const r = await this.post('/api/visitas', {id_propiedad:this.pid,fecha_hora:new Date(this.fechaVisita).toISOString(),...(this.staff?{id_cliente:this.clienteVisita}:{})}); this.message.set(r.pendiente?'Propuesta de visita guardada; pendiente de sincronización.':'Visita confirmada por el servidor.'); }); }
 activarPush() { void this.act(async () => { this.message.set(await this.push.activar()); }); }
 pruebaPush() { void this.act(async () => { const r = await this.post('/api/notificaciones/prueba'); this.message.set(r.push_enviado ? 'FCM aceptó el mensaje. Revisa tu dispositivo.' : 'Prueba guardada en la bandeja; no se confirmó un envío push. Revisa Firebase y activa este dispositivo.'); }); }
 exportar(formato: string) { void this.act(async () => { const blob = await firstValueFrom(this.http.get(API + '/api/reportes/ejecutivo', {params: {formato}, responseType: 'blob'})); const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = 'reporte-ejecutivo.' + formato; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }); }
}
