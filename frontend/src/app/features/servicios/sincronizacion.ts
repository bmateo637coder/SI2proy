import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Sprint4Offline } from '../../core/services/sprint4-offline.service';
@Component({standalone:true,imports:[CommonModule],template:`<main style="padding:2rem"><h1>Sincronización de servicios</h1>
 <p>Las propuestas permanecen aquí hasta que el servidor las confirme. Un conflicto conserva los datos del servidor.</p>
 <button class="btn-primary" (click)="sincronizar()">Sincronizar ahora</button><p role="status">{{message()}}</p>
 <article *ngFor="let row of rows()" class="luxury-card" style="margin-top:1rem"><h2>{{row.state}}</h2><p>{{row.command.metodo}} {{row.command.ruta}}</p>
  <h3>Propuesta local</h3><pre style="white-space:pre-wrap">{{row.command.datos | json}}</pre>
  <ng-container *ngIf="row.error"><h3>Respuesta del servidor</h3><pre style="white-space:pre-wrap">{{row.error | json}}</pre></ng-container>
  <button *ngIf="row.error?.servidor?.version" class="btn-primary" (click)="reproponer(row.uuid)">Volver a proponer mis cambios sobre la versión mostrada</button>
  <button class="btn-secondary" (click)="descartar(row.uuid)">Descartar propuesta y sus dependencias</button></article>
 <p *ngIf="!rows().length">No hay cambios pendientes.</p></main>`})
export class SincronizacionServicios{
 readonly service=inject(Sprint4Offline);readonly rows=signal<any[]>([]);readonly message=signal('');
 constructor(){void this.load();}async load(){this.rows.set(await this.service.rows());}
 async sincronizar(){await this.service.sync();await this.load();this.message.set('Revisión terminada. Los cambios pendientes se reintentarán al recuperar conexión.');}
 async descartar(id:string){await this.service.discard(id);await this.load();}
 async reproponer(id:string){await this.service.rebase(id);await this.load();}
}
