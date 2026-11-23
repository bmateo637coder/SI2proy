import { Component, OnDestroy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { Subscription } from 'rxjs';
import { API, authHeaders, errorTexto } from '../../core/services/api';
import { currencyConvert } from '../../core/services/currency-math';

@Component({standalone:true,imports:[CommonModule,FormsModule],styleUrl:'../parcial2.css',template:`
<section class="p2-page">
  <header><div><h1>Predicción de ventas y demanda</h1><p>Proyección mensual, historial y validación temporal.</p></div><button (click)="load()" [disabled]="busy">Actualizar</button></header>
  <div class="filters"><label>Datos del modelo<select aria-label="Datos del modelo" [(ngModel)]="mode" (change)="load()"><option value="real">Historial de esta selección</option><option value="demo">Escenario académico de demostración</option></select></label>
    <label>Horizonte<select aria-label="Horizonte" [(ngModel)]="horizon"><option [ngValue]="1">1 mes</option><option [ngValue]="3">3 meses</option><option [ngValue]="6">6 meses</option></select></label></div>
  <p *ngIf="busy" role="status">Calculando modelo…</p><p *ngIf="error" role="alert">{{error}}</p>
  <ng-container *ngIf="data">
    <div class="notice"><strong>{{data.modo === 'demo' ? 'DEMOSTRACIÓN · DATOS SINTÉTICOS' : 'Historial del alcance seleccionado'}}</strong><p>{{data.advertencia}}</p><small>Actualización: {{data.generado_en | date:'medium'}} · Último mes completo: {{data.hasta}}</small></div>
    <div class="cards"><article *ngFor="let key of keys"><h2>{{key === 'ventas' ? 'Ventas' : 'Demanda: visitas'}}</h2><p>{{data.definiciones[key]}}</p>
      <p>{{data[key].eventos}} eventos en {{data[key].meses_entrenamiento}} meses.</p>
      <p *ngIf="data[key].estado !== 'calculado'">Historial insuficiente. Agrega actividad de al menos 6 meses y 6 eventos, o selecciona la demostración.</p>
      <ng-container *ngIf="data[key].estado === 'calculado'"><p><b>{{data[key].modelo}}</b></p><small>MAE temporal: {{data[key].mae_validacion}} eventos · Base: {{data[key].mae_base}} · Ridge: {{data[key].mae_modelo_ml}} · {{data[key].meses_validacion}} meses de validación</small>
        <div class="chart"><div *ngFor="let row of data[key].proyeccion.slice(0,horizon)"><div class="chart-label">{{row.mes}} · {{row.cantidad | number:'1.0-2'}} estimados</div><div class="bar" [style.width.%]="bar(key,row.cantidad)"></div></div></div>
      </ng-container>
      <details><summary>Ver historial mensual</summary><div class="table-scroll"><table><tr><th>Mes</th><th>Eventos</th></tr><tr *ngFor="let row of data[key].historial"><td>{{row.mes}}</td><td>{{row.cantidad}}</td></tr></table></div></details>
    </article></div>
    <button (click)="csv()">Exportar proyección CSV</button>
  </ng-container>
</section>`})
export class PredictionsPage implements OnDestroy {
  private cdr=inject(ChangeDetectorRef); private http=inject(HttpClient); private request?:Subscription;
  data:any=null; busy=false; error=''; mode='real'; horizon=3; keys=['ventas','demanda'];
  constructor(){this.load();}
  ngOnDestroy(){this.request?.unsubscribe();}
  load(){this.request?.unsubscribe();this.busy=true;this.error='';this.data=null;
    this.request=this.http.get(API+'/api/predicciones',{headers:authHeaders(),params:this.mode==='demo'?{modo:'demo'}:{}}).subscribe({
      next:r=>{this.data=r;this.busy=false;this.cdr.markForCheck();},error:e=>{this.error=errorTexto(e,'No se pudieron cargar las predicciones. Conéctate para calcularlas por primera vez.');this.busy=false;this.cdr.markForCheck();}});}
  bar(key:string,value:number){return Math.max(1,100*value/Math.max(1,...this.data[key].proyeccion.map((r:any)=>r.cantidad)));}
  csv(){const rows=[['modo','serie','mes','estimado'],...this.keys.flatMap(key=>this.data[key].proyeccion.slice(0,this.horizon).map((r:any)=>[this.data.modo,key,r.mes,r.cantidad]))];
    const url=URL.createObjectURL(new Blob(['\uFEFF'+rows.map(r=>r.join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download='predicciones.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
}

@Component({standalone:true,imports:[CommonModule,FormsModule],styleUrl:'../parcial2.css',template:`
<section class="p2-page"><header><div><h1>Conversión multimoneda</h1><p>Importes de referencia y tipo de cambio con fecha.</p></div><button (click)="load()" [disabled]="busy">Actualizar tasas</button></header>
  <p *ngIf="busy" role="status">Consultando tasas…</p><p *ngIf="error" role="alert">{{error}}</p>
  <div class="filters"><label>Monto<input aria-label="Monto a convertir" type="text" inputmode="decimal" [(ngModel)]="amount"></label>
    <label>Origen<select aria-label="Moneda de origen" [(ngModel)]="origin" (change)="manual=''" ><option *ngFor="let c of currencies" [value]="c">{{c}}</option></select></label>
    <button (click)="swap()" aria-label="Invertir monedas">⇄</button>
    <label>Destino<select aria-label="Moneda de destino" [(ngModel)]="target" (change)="manual=''"><option *ngFor="let c of currencies" [value]="c">{{c}}</option></select></label></div>
  <details><summary>Usar una tasa manual</summary><label>Tasa manual: 1 {{origin}} = unidades de {{target}}<input aria-label="Tasa manual" inputmode="decimal" [(ngModel)]="manual" placeholder="Opcional"></label></details>
  <article class="notice" style="margin:1rem 0" aria-live="polite"><h2>{{result() === null ? 'Revisa el monto y las tasas' : result() + ' ' + target}}</h2><p>{{manual ? 'Conversión con la tasa manual ingresada.' : 'Conversión con las tasas de referencia descargadas.'}}</p></article>
  <ng-container *ngIf="data"><p *ngIf="data.vencidas" role="status">La tasa guardada está vencida; revisa su fecha antes de usarla.</p><p>Fecha de la tasa: {{data.actualizado_en | date:'medium'}}</p>
    <a [href]="data.fuente_url" target="_blank" rel="noopener">Rates By {{data.fuente}}</a><p>{{data.aviso}}</p>
    <div class="table-scroll"><table><tr><th>Moneda</th><th>Por 1 USD</th></tr><tr *ngFor="let c of currencies"><td>{{c}}</td><td>{{data.tasas[c]}}</td></tr></table></div></ng-container>
  <p>USD, BOB (boliviano), EUR (euro), BRL (real), CLP (peso chileno), PEN (sol). Sin conexión puedes convertir con la última descarga o ingresar una tasa manual. Los contratos y pagos conservan sus importes originales en USD.</p>
</section>`})
export class CurrencyPage implements OnDestroy {
  private cdr=inject(ChangeDetectorRef); private http=inject(HttpClient);private request?:Subscription;
  currencies=['USD','BOB','EUR','BRL','CLP','PEN'];amount='100';origin='USD';target='BOB';manual='';data:any=null;busy=false;error='';
  constructor(){this.load();}
  ngOnDestroy(){this.request?.unsubscribe();}
  load(){this.request?.unsubscribe();this.busy=true;this.error='';this.request=this.http.get<any>(API+'/api/moneda',{headers:authHeaders()}).subscribe({next:r=>{this.data={...r,vencidas:r.vencidas||Date.now()/1000>=r.proxima_actualizacion_unix};this.busy=false;this.cdr.markForCheck();},error:e=>{this.error=errorTexto(e,'No se pudieron actualizar las tasas. Puedes ingresar una tasa manual.');this.busy=false;this.cdr.markForCheck();}});}
  swap(){[this.origin,this.target]=[this.target,this.origin];this.manual='';}
  result(){return this.manual?currencyConvert(this.amount,'1',this.manual):this.origin===this.target?currencyConvert(this.amount,'1','1'):this.data?currencyConvert(this.amount,this.data?.tasas?.[this.origin],this.data?.tasas?.[this.target]):null;}
}
