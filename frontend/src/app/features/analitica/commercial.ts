import { Component, ChangeDetectorRef, inject, effect, OnDestroy, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { Subscription, forkJoin } from 'rxjs';
import { API, authHeaders, errorTexto } from '../../core/services/api';
import { AuthService } from '../../core/services/auth.service';

@Component({selector:'app-commercial',standalone:true,imports:[CommonModule,FormsModule],styleUrl:'../parcial2.css',styles:[`
.board{display:flex;gap:14px;overflow-x:auto;padding:12px 0;align-items:flex-start}.lane{flex:0 0 285px;background:#edf3f4;border-radius:16px;padding:12px;min-height:200px}.deal{background:white;border:1px solid #dbe5e7;border-radius:12px;padding:14px;margin:12px 0;color:#16313b}.deal h3{margin:0 0 10px}.deal select{max-width:100%}.form-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}.panel{background:white;border:1px solid #dbe5e7;border-radius:16px;padding:18px;margin:16px 0}.tasks{display:grid;gap:12px}.tasks label{display:flex;align-items:center;gap:10px}.tasks input{width:auto}textarea{width:100%;min-height:80px}button{margin:4px} .overdue{color:#a32929}@media(max-width:600px){.lane{flex-basis:82vw}.p2-page{padding:12px}}
`],template:`<section class="p2-page">
<header><div><h1>{{workflow?'Workflow inteligente con IA':'Embudo comercial · Kanban'}}</h1><p>{{workflow?'Clasifica consultas, prioriza el seguimiento y registra tareas.':'Gestiona prospectos desde el primer contacto hasta el cierre.'}}</p></div><button (click)="load()" [disabled]="busy">Actualizar</button></header>
<p *ngIf="auth.allTenants()">Vista consolidada por inmobiliaria. Selecciona una empresa para registrar cambios.</p>
<p role="alert" *ngIf="error">{{error}}</p><p role="status" *ngIf="notice">{{notice}}</p><p *ngIf="busy" role="status">Cargando…</p>
<ng-container *ngIf="!workflow">
<div class="filters"><label>Buscar<input aria-label="Buscar oportunidades" [(ngModel)]="search"></label><label>Responsable<select [(ngModel)]="agent"><option value="">Todos</option><option *ngFor="let a of options.agentes" [value]="a.id">{{a.nombre}}</option></select></label><button (click)="edit()" [disabled]="readonly||busy">Nueva oportunidad</button></div>
<p>{{filtered.length}} oportunidades · Abierto: {{openTotal | number:'1.2-2'}} USD · Ponderado: {{weighted | number:'1.2-2'}} USD</p>
<form *ngIf="form" class="panel" (ngSubmit)="save()"><h2>{{form.id?'Editar':'Nueva'}} oportunidad</h2><div class="form-grid">
<label>Título<input name="titulo" aria-label="Título de oportunidad" [(ngModel)]="form.titulo" required minlength="3" maxlength="150"></label><label>Contacto<input name="contacto" aria-label="Contacto" [(ngModel)]="form.contacto" required minlength="3" maxlength="200"></label>
<label>Importe USD<input name="importe" type="number" min="0" max="999999999999" step="0.01" [(ngModel)]="form.importe" required></label><label>Probabilidad %<input name="probabilidad" type="number" min="0" max="100" step="1" [(ngModel)]="form.probabilidad" required></label>
<label>Etapa<select name="etapa" [(ngModel)]="form.etapa"><option *ngFor="let s of stages">{{s}}</option></select></label><label>Próximo contacto<input name="proximo" type="date" [(ngModel)]="form.proximo_contacto"></label>
<label *ngFor="let ref of refs">{{ref.label}}<select [name]="ref.key" [(ngModel)]="form[ref.key]"><option [ngValue]="null">Sin asignar</option><option *ngFor="let item of options[ref.list]" [ngValue]="item.id">{{item.nombre}}</option></select></label></div>
<label>Notas<textarea name="notas" maxlength="3000" [(ngModel)]="form.notas"></textarea></label><button type="submit" [disabled]="busy||readonly">Guardar oportunidad</button><button type="button" (click)="form=null">Cancelar</button></form>
<p>Arrastra una tarjeta o utiliza su selector de etapa. «Ganado» registra el cierre comercial; los contratos y cobros se gestionan en sus módulos.</p>
<div class="board" aria-label="Pipeline Kanban"><section class="lane" *ngFor="let stage of stages" (dragover)="$event.preventDefault()" (drop)="drop($event,stage)"><h2>{{stage}} · {{inStage(stage).length}}</h2><p>{{stageTotal(stage)|number:'1.2-2'}} USD</p>
<article class="deal" *ngFor="let r of inStage(stage)" [draggable]="!readonly&&!busy" (dragstart)="drag($event,r)"><h3>{{r.titulo}}</h3><p>{{r.inmobiliaria}} · {{r.contacto}}</p><strong>{{r.importe|number:'1.2-2'}} USD · {{r.probabilidad}}%</strong><p [class.overdue]="late(r)">Próximo contacto: {{r.proximo_contacto||'Sin programar'}}</p><p *ngIf="r.pendiente">Pendiente de sincronizar</p><label>Etapa<select [attr.aria-label]="'Etapa de '+r.titulo" [ngModel]="r.etapa" (ngModelChange)="move(r,$event)" [disabled]="readonly||busy"><option *ngFor="let s of stages">{{s}}</option></select></label><button (click)="edit(r)" [disabled]="readonly||busy">Editar</button><button (click)="archive(r)" [disabled]="readonly||busy">Archivar</button><details><summary>Historial</summary><p *ngFor="let h of r.historial">{{h.fecha|date:'short'}} · {{h.usuario}} · {{h.accion}}</p></details></article><p *ngIf="!inStage(stage).length">Sin oportunidades</p></section></div>
</ng-container>
<ng-container *ngIf="workflow"><form class="panel" (ngSubmit)="generate()"><label>Consulta o situación comercial<textarea aria-label="Consulta comercial" name="texto" [(ngModel)]="text" required minlength="5" maxlength="3000" placeholder="El cliente quiere visitar una casa hoy y conocer las condiciones de compra"></textarea></label>
<label>Oportunidad vinculada<select name="opportunity" [(ngModel)]="opportunity"><option [ngValue]="null">Sin vincular</option><option *ngFor="let r of opportunities" [ngValue]="r.id">{{r.titulo}}</option></select></label><button type="submit" [disabled]="readonly||busy">Generar plan de seguimiento</button></form>
<p>Gemini clasifica cuando está disponible; en otro caso se aplican reglas locales identificadas. Revisa las tareas antes de ejecutarlas. No se envían mensajes ni se crean contratos automáticamente.</p>
<label>Mostrar<select [(ngModel)]="status"><option value="">Todos</option><option>Pendiente</option><option>Completado</option></select></label>
<article class="panel" *ngFor="let r of visibleWorkflows"><h2>{{r.categoria}} · {{r.urgencia}}</h2><p>{{r.inmobiliaria}} · {{r.estado}} · {{r.modo==='gemini'?'Clasificación Gemini':r.pendiente?'Reglas locales; pendiente de sincronizar':'Reglas locales'}}</p><p>{{r.texto}}</p><p>{{r.justificacion}}</p><p *ngIf="r.id_oportunidad">Oportunidad #{{r.id_oportunidad}}</p><div class="tasks"><label *ngFor="let t of r.tareas;let i=index"><input type="checkbox" [checked]="t.completada" [disabled]="readonly||busy" (change)="task(r,i,!t.completada)"><span>{{t.titulo}} · {{t.vence}}</span></label></div><details><summary>Historial</summary><p *ngFor="let h of r.historial">{{h.fecha|date:'short'}} · {{h.usuario}} · {{h.accion}}</p></details></article><p *ngIf="!rows.length&&!busy">Todavía no hay planes de seguimiento.</p></ng-container></section>`})
export class CommercialPage implements OnDestroy {
  @Input() workflow=false;
  auth=inject(AuthService);private http=inject(HttpClient);private cdr=inject(ChangeDetectorRef);private req=new Subscription();private generation=0;
  rows:any[]=[];opportunities:any[]=[];options:any={};busy=false;error='';notice='';search='';agent='';form:any=null;text='';opportunity:number|null=null;status='';
  stages=['Nuevo','Contactado','Visita','Negociacion','Ganado','Perdido'];refs=[{label:'Cliente',key:'id_cliente',list:'clientes'},{label:'Inmueble',key:'id_propiedad',list:'propiedades'},{label:'Responsable',key:'id_agente',list:'agentes'}];
  constructor(){effect(()=>{this.auth.selectedTenant();this.auth.currentUser();this.form=null;this.opportunity=null;this.load();});}
  get readonly(){return this.auth.allTenants()||!this.auth.tenantId();}
  ngOnDestroy(){this.generation++;this.req.unsubscribe();}
  load(){const gen=++this.generation;this.req.unsubscribe();this.req=new Subscription();this.busy=true;this.error='';this.rows=[];
    this.req.add(forkJoin([this.http.get<any[]>(API+(this.workflow?'/api/workflow-ia':'/api/oportunidades'),{headers:authHeaders()}),this.http.get<any>(API+'/api/oportunidades/opciones',{headers:authHeaders()}),this.http.get<any[]>(API+'/api/oportunidades',{headers:authHeaders()})]).subscribe({next:([rows,options,opps])=>{if(gen!==this.generation)return;this.rows=rows;this.options=options;this.opportunities=opps;this.busy=false;this.cdr.markForCheck();},error:e=>{if(gen!==this.generation)return;this.error=errorTexto(e,'No se pudo cargar el módulo comercial.');this.busy=false;this.cdr.markForCheck();}}));}
  get filtered(){const q=this.search.toLocaleLowerCase();return this.rows.filter(r=>(!this.agent||String(r.id_agente)===String(this.agent))&&`${r.titulo} ${r.contacto} ${r.inmobiliaria}`.toLocaleLowerCase().includes(q));}
  inStage(stage:string){return this.filtered.filter(r=>r.etapa===stage);}
  stageTotal(stage:string){return this.inStage(stage).reduce((s,r)=>s+Number(r.importe||0),0);}
  get openTotal(){return this.filtered.filter(r=>!['Ganado','Perdido'].includes(r.etapa)).reduce((s,r)=>s+Number(r.importe||0),0);}
  get weighted(){return this.filtered.filter(r=>!['Ganado','Perdido'].includes(r.etapa)).reduce((s,r)=>s+Number(r.importe||0)*Number(r.probabilidad||0)/100,0);}
  get visibleWorkflows(){return this.rows.filter(r=>!this.status||r.estado===this.status);}
  late(r:any){return r.proximo_contacto&&r.proximo_contacto<new Date().toLocaleDateString('en-CA')&&!['Ganado','Perdido'].includes(r.etapa);}
  edit(row?:any){this.form=row?structuredClone(row):{titulo:'',contacto:'',importe:0,probabilidad:10,etapa:'Nuevo',notas:'',proximo_contacto:null,id_cliente:null,id_propiedad:null,id_agente:null};}
  payload(r:any){return Object.fromEntries(['titulo','contacto','importe','probabilidad','etapa','notas','id_cliente','id_propiedad','id_agente'].map(k=>[k,r[k]??null]).concat([['proximo_contacto',r.proximo_contacto||null],...(r.version?[['version',r.version]]:[])]));}
  write(method:string,path:string,data:any){if(this.readonly||this.busy)return;const gen=this.generation;this.busy=true;this.error='';this.notice='';this.req.add(this.http.request<any>(method,API+path,{headers:authHeaders(),body:data}).subscribe({next:r=>{if(gen!==this.generation)return;this.notice=r.pendiente?'Cambio guardado sin conexión; revisa la sincronización al reconectarte.':'Cambio guardado.';this.form=null;this.load();},error:e=>{if(gen!==this.generation)return;this.error=errorTexto(e,'No se pudo guardar. Revisa Sincronizar servicios si existe un conflicto.');this.busy=false;this.cdr.markForCheck();}}));}
  save(){this.write(this.form.id?'PUT':'POST','/api/oportunidades'+(this.form.id?'/'+this.form.id:''),this.payload(this.form));}
  move(r:any,stage:string){if(stage!==r.etapa)this.write('PUT','/api/oportunidades/'+r.id,this.payload({...r,etapa:stage}));}
  archive(r:any){if(confirm('¿Archivar esta oportunidad? Se conservará su historial.'))this.write('DELETE','/api/oportunidades/'+r.id,{version:r.version||1});}
  drag(e:DragEvent,r:any){e.dataTransfer?.setData('text/plain',String(r.id));}
  drop(e:DragEvent,stage:string){e.preventDefault();const r=this.rows.find(r=>String(r.id)===e.dataTransfer?.getData('text/plain'));if(r)this.move(r,stage);}
  generate(){this.write('POST','/api/workflow-ia',{texto:this.text,id_oportunidad:this.opportunity});}
  task(r:any,i:number,done:boolean){this.write('PUT','/api/workflow-ia/'+r.id,{version:r.version||1,tarea:i,completada:done});}
}

@Component({standalone:true,imports:[CommercialPage],template:'<app-commercial [workflow]="true" />'})
export class WorkflowPage {}
