import { Injectable, inject, signal, effect } from '@angular/core';
import { HttpBackend, HttpClient, HttpHeaders, HttpInterceptorFn, HttpRequest, HttpResponse } from '@angular/common/http';
import { from, firstValueFrom } from 'rxjs';
import { AuthService } from './auth.service';
import { API } from './api';
import { localCommercialPlan } from './commercial-offline';

type Pending = { uuid: string; identity: string; account: string; scope: string; command: any; local: number; state: string; result?: any; error?: any };
@Injectable({providedIn:'root'})
export class Sprint4Offline {
 private auth=inject(AuthService); private http=new HttpClient(inject(HttpBackend));
 readonly message=signal(''); readonly pending=signal(0); readonly conflicts=signal(0);
 private db?: Promise<IDBDatabase>; private working=false; private downloading=false; private last='';
 constructor() {
  effect(()=>{const user=this.auth.currentUser(); const scope=this.auth.selectedTenant(); if(user){const key=this.account; if(key!==this.last){this.last=key;void this.download();}}});
  if(typeof window!=='undefined') { window.addEventListener('online',()=>void this.sync()); setInterval(()=>{if(navigator.onLine)void this.sync();},30000); }
 }
 get identity(){const u=this.auth.currentUser();return `${API}|${u?.ci}|${u?.id_rol}|${[...(u?.permisos||[])].sort().join(',')}|`;}
 get scope(){return this.auth.allTenants()?'all':String(this.auth.tenantId()||0);}
 get account(){return this.identity+this.scope;}
 private open(){return this.db??=new Promise<IDBDatabase>((resolve,reject)=>{const r=indexedDB.open('raices-servicios-v1',1);r.onupgradeneeded=()=>{r.result.createObjectStore('cache');r.result.createObjectStore('queue',{keyPath:'uuid'});};r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
 private async operation(store:string,mode:IDBTransactionMode,fn:(s:IDBObjectStore)=>IDBRequest):Promise<any>{const db=await this.open();return new Promise((resolve,reject)=>{const tx=db.transaction(store,mode);const req=fn(tx.objectStore(store));tx.oncomplete=()=>resolve(req.result);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});}
 private getCache(key:string){return this.operation('cache','readonly',s=>s.get(key));}
 private putCache(key:string,value:any){return this.operation('cache','readwrite',s=>s.put(value,key));}
 private headers(scope=this.scope){let h=new HttpHeaders({Authorization:`Bearer ${localStorage.getItem('token')}`});return scope==='all'?h.set('X-Tenant-Scope','all'):Number(scope)>0?h.set('X-Tenant-ID',scope):h;}
 private offline(e:any){return !e.status || e.status>=500;}
 async rows():Promise<Pending[]>{const rows:Pending[]=await this.operation('queue','readonly',s=>s.getAll());return rows.filter(r=>r.identity===this.identity && r.state!=='confirmado');}
 private async counts(){const rows=await this.rows();this.pending.set(rows.filter(r=>r.state==='pendiente').length);this.conflicts.set(rows.filter(r=>r.state==='conflicto').length);}
 async sync(){if(this.working||!this.auth.currentUser()||!navigator.onLine)return;this.working=true;const owner=this.identity;
  try {const rows=(await this.rows()).sort((a,b)=>b.local-a.local);for(const row of rows){if(row.state!=='pendiente'||owner!==this.identity)continue;await this.send(row);}await this.counts();}
  catch{} finally{this.working=false;}
 }
 private async send(row:Pending){
  const command=structuredClone(row.command), match=command.ruta.match(/\/-\d+/);
  const dependency=command.datos?.id_oportunidad;
  if(Number(dependency)<0){const all:Pending[]=await this.operation('queue','readonly',s=>s.getAll());const parent=all.find(r=>r.account===row.account&&r.local===dependency);if(!parent||parent.state!=='confirmado')return;command.datos.id_oportunidad=parent.result.id;}
  if(match){const all:Pending[]=await this.operation('queue','readonly',s=>s.getAll());const parent=all.find(r=>r.account===row.account&&r.local===Number(match[0].slice(1)));
   if(!parent||parent.state!=='confirmado')return;command.ruta=command.ruta.replace(match[0],`/${parent.result.id}`);}
  try {const result=await firstValueFrom(this.http.post(API+'/api/servicios/sync',command,{headers:this.headers(row.scope)}));
   row.state='confirmado';row.result=result;row.error=null;
  }catch(e:any){if(this.offline(e)||e.status===401)return;row.state='conflicto';row.error=e.error?.detail||'No se pudo confirmar el cambio.';}
  await this.operation('queue','readwrite',s=>s.put(row));
 }
 async discard(uuid:string){const all:Pending[]=await this.operation('queue','readonly',s=>s.getAll());const row=all.find(r=>r.uuid===uuid&&r.identity===this.identity);if(!row)return;
  for(const item of all.filter(r=>r.identity===this.identity&&(r.uuid===uuid||r.command.ruta.includes(`/${row.local}`))))await this.operation('queue','readwrite',s=>s.delete(item.uuid));await this.counts();}
 async rebase(uuid:string){const row=(await this.rows()).find(r=>r.uuid===uuid);if(!row?.error?.servidor?.version)return;
  const id=crypto.randomUUID();const updated={...row,uuid:id,state:'pendiente',error:null,command:{...row.command,uuid:id,version:row.error.servidor.version}};
  await this.operation('queue','readwrite',s=>{s.delete(uuid);return s.put(updated);});await this.sync();}
 async request(req:HttpRequest<any>):Promise<HttpResponse<any>>{
  const account=this.account, owner=this.identity, scope=this.scope;
  if(req.method==='POST'&&/\/(busqueda-semantica|servicios\/ia\/(chat|cotizar|descripcion))$/.test(req.url)){
   const key=account+'|'+req.url+'|'+JSON.stringify(req.body);
   try{const result=await firstValueFrom(this.http.post(req.url,req.body,{headers:req.headers}));if(account===this.account)await this.putCache(key,result);return new HttpResponse({status:200,body:result});}
   catch(e:any){if(!this.offline(e))throw e;const saved=await this.getCache(key);this.message.set('Sin conexión: búsqueda y asistente locales. Gemini requiere Internet.');
    if(saved!==undefined)return new HttpResponse({status:200,body:{...saved,modo:'respuesta_guardada_offline'}});
    const catalog=await this.getCache(account+'|'+API+'/modulo_inmuebles/propiedades/catalogo');if(!catalog)throw e;
    if(req.url.endsWith('/busqueda-semantica')){
     let text=String(req.body.texto||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'');
     for(const [word,value] of Object.entries({dos:2,tres:3,cuatro:4,cinco:5}))text=text.replace(new RegExp('\\b'+word+'\\b','g'),String(value));
     const amount=text.match(/(?:hasta|maximo|menos de)\s*\$?\s*(\d+(?:[.,]\d+)*)\s*(mil|k|millones)?/);
     let max=amount?Number(/^\d{1,3}([.,]\d{3})+$/.test(amount[1])?amount[1].replace(/[.,]/g,''):amount[1].replace(',','.')):Infinity;
     if(amount?.[2])max*=amount[2]==='millones'?1000000:1000;
     const rooms=Number(text.match(/(\d+)\s*(habitacion|cuarto|dormitorio)/)?.[1]||0);
     const operation=/alquil/.test(text)?'Alquiler':/anticr/.test(text)?'Anticretico':/venta|compr/.test(text)?'Venta':null;
     const type=['casa','departamento','local','terreno','oficina'].find(t=>text.includes(t));
     const result=catalog.filter((p:any)=>p.estado==='Disponible'&&(!operation||p.tipo_operacion===operation)&&Number(p.precio)<=max&&(!type||p.titulo.toLowerCase().includes(type))&&(!rooms||Number(p.caracteristicas?.find((c:any)=>/^(habitaciones|cuartos|dormitorios)$/i.test(c.nombre))?.valor||0)>=rooms));
     return new HttpResponse({status:200,body:{resultados:result,total:result.length,resumen:'Filtros básicos locales sobre la última descarga',modo:'reglas_offline'}});
    }
    const p=catalog.find((p:any)=>p.id_propiedad===req.body.id_propiedad);
    const response=req.url.endsWith('/descripcion')&&p?`${p.titulo}, en ${p.direccion}. ${p.tipo_operacion} por ${p.precio}. ${p.descripcion||''}`:req.url.endsWith('/cotizar')&&p?`Precio publicado: ${p.precio}. La tasación predictiva requiere consultar el modelo del servidor.`:`Tu copia contiene ${catalog.length} inmuebles. Puedes buscar, guardar favoritos y crear alertas; los cambios se sincronizarán al recuperar conexión.`;
    return new HttpResponse({status:200,body:{respuesta:response,modo:'asistente_local_offline'}});
   }
  }
  if(req.method==='GET'){
   try {const result=await firstValueFrom(this.http.request(req.method,req.url,{body:req.body,headers:req.headers,params:req.params,responseType:req.responseType as 'json'}));
    if(account===this.account)await this.putCache(account+'|'+req.urlWithParams,result);
    return new HttpResponse({status:200,body:await this.project(req.url,result,account)});
   }catch(e:any){if(!this.offline(e))throw e;const cached=await this.getCache(account+'|'+req.urlWithParams);if(cached===undefined)throw e;
    this.message.set('Sin conexión: se muestran datos de la última descarga y propuestas pendientes.');return new HttpResponse({status:200,body:await this.project(req.url,cached,account)});}
  }
  let body=req.body||{};
  if(body instanceof FormData){const file=body.get('file');if(!(file instanceof File))throw new Error('Seleccione una imagen.');if(file.size>5*1024*1024)throw new Error('La foto no puede superar 5 MB.');
   const bytes=new Uint8Array(await file.arrayBuffer());let binary='';for(let i=0;i<bytes.length;i+=32768)binary+=String.fromCharCode(...bytes.subarray(i,i+32768));body={contenido:btoa(binary)};}
  if(owner!==this.identity||account!==this.account)throw new Error('La cuenta o inmobiliaria cambió.');
  const uuid=crypto.randomUUID(), local=-Date.now()*1000-Math.floor(Math.random()*999);
  const path=req.url.slice(API.length);const command:any={uuid,metodo:req.method,ruta:path,datos:body};
  if(body.version)command.version=body.version;
  if(/^\/api\/mantenimiento\/\d+$/.test(path)&&req.method==='PUT'){const base=await this.getCache(account+'|'+req.url);if(base?.version)command.version=base.version;}
  const row:Pending={uuid,identity:owner,account,scope,command,local,state:'pendiente'};
  await this.operation('queue','readwrite',s=>s.put(row));await this.send(row);await this.counts();
  if(row.state==='conflicto')throw {status:409,error:{detail:typeof row.error==='string'?row.error:'Hay un conflicto. Revise Sincronización de servicios.'}};
  if(row.state==='confirmado')return new HttpResponse({status:200,body:row.result});
  this.message.set('Cambio guardado en este navegador. Pendiente de sincronización.');
  return new HttpResponse({status:200,body:{...body,id:local,pendiente:true,estado:'Pendiente de sincronizar',categoria:'Pendiente',urgencia:'Pendiente',resumen:body.texto||'Criterios guardados',coincidencias_actuales:0}});
 }
 private async project(url:string,value:any,account:string){
  if(!Array.isArray(value))return value;const path=url.slice(API.length), result=structuredClone(value);
  const all:Pending[]=await this.operation('queue','readonly',s=>s.getAll());
  for(const row of all.filter(r=>r.account===account&&r.state==='pendiente').sort((a,b)=>b.local-a.local)){
   const c=row.command;if(path==='/api/favoritos'&&c.ruta.startsWith(path+'/')){const id=Number(c.ruta.split('/').pop());const index=result.findIndex((f:any)=>f.id_propiedad===id);if(index>=0)result.splice(index,1);
    if(c.metodo==='POST'){const catalog=await this.getCache(account+'|'+API+'/modulo_inmuebles/propiedades/catalogo');const p=catalog?.find((p:any)=>p.id_propiedad===id);if(p)result.push({id_propiedad:id,propiedad:p,disponible:p.estado==='Disponible',pendiente:true});}
   }else if(c.ruta===path&&c.metodo==='POST'&&['/api/oportunidades','/api/workflow-ia'].includes(path)){const data={...c.datos,id:row.local,version:1,pendiente:true,inmobiliaria:'Inmobiliaria seleccionada',historial:[]};result.push(path.endsWith('workflow-ia')?{...data,...localCommercialPlan(c.datos.texto)}:data);}
   else if(path==='/api/workflow-ia'&&c.ruta.startsWith(path+'/')&&c.metodo==='PUT'){const item=result.find((r:any)=>r.id===Number(c.ruta.split('/').pop()));if(item?.tareas?.[c.datos.tarea]){item.tareas[c.datos.tarea].completada=c.datos.completada;item.estado=item.tareas.every((t:any)=>t.completada)?'Completado':'Pendiente';item.version++;item.pendiente=true;}}
   else if(c.ruta===path&&c.metodo==='POST'&&['/api/alertas','/api/mantenimiento','/api/visitas'].includes(path)){result.push({...c.datos,id:row.local,id_visita:row.local,activa:true,resumen:c.datos.texto||'Criterios guardados',estado:'Pendiente de sincronizar',urgencia:'Pendiente',pendiente:true});}
   else if(c.ruta.startsWith(path+'/')&&!c.ruta.slice(path.length+1).includes('/')){const id=Number(c.ruta.split('/').pop()),i=result.findIndex((r:any)=>r.id===id);if(i>=0&&c.metodo==='DELETE')result.splice(i,1);else if(i>=0&&c.metodo==='PUT')result[i]={...result[i],...c.datos,version:(result[i].version||0)+1,pendiente:true};}
  }if(path==='/api/oportunidades')for(const r of result){if(r.etapa==='Ganado')r.probabilidad=100;if(r.etapa==='Perdido')r.probabilidad=0;}return result;
 }
 private async download(){if(this.downloading||!navigator.onLine)return;this.downloading=true;const account=this.account;
  try {await this.sync();const u=this.auth.currentUser();const staff=u?.id_rol===1||u?.id_rol===2||u?.es_agente;
   const paths=['/api/moneda','/modulo_inmuebles/propiedades/catalogo','/api/favoritos','/api/alertas','/api/recomendaciones','/api/bandeja','/api/mi-cuenta','/api/mantenimiento','/api/mantenimiento/mis-inmuebles','/api/visitas',
    ...(staff?['/api/oportunidades','/api/oportunidades/opciones','/api/workflow-ia','/api/predicciones','/api/gerencia/dashboard','/api/analitica/zonas','/api/comisiones','/api/promociones','/api/reportes/ejecutivo']:[])];
   for(const path of paths){if(account!==this.account)return;try{const r=await firstValueFrom(this.http.get<any>(API+path,{headers:this.headers()}));await this.putCache(account+'|'+API+path,r);
    if(path==='/api/mantenimiento')for(const item of r){const url=API+path+'/'+item.id;const detail=await firstValueFrom(this.http.get(url,{headers:this.headers()}));await this.putCache(account+'|'+url,detail);}}catch{ /* Optional services must not stop the rest of the offline download. */ }}
  }catch{}finally{this.downloading=false;}
 }
}

export const sprint4Interceptor:HttpInterceptorFn=(req,next)=>{
 const path=req.url.startsWith(API)?req.url.slice(API.length):'';
 const commercial=/^\/api\/(oportunidades|workflow-ia)(?:\/-?\d+)?$/.test(path);
 const reads=req.method==='GET'&&(/^\/(api\/(moneda|predicciones|visitas|favoritos|alertas|recomendaciones|bandeja|mantenimiento|gerencia|analitica\/zonas|comisiones|promociones|mi-cuenta|reportes\/ejecutivo)|modulo_inmuebles\/propiedades\/catalogo)/.test(path)||commercial||path==='/api/oportunidades/opciones');
 const writes=['POST','PUT','DELETE'].includes(req.method)&&/^\/api\/(visitas(?:\/-?\d+)?|favoritos(?:\/-?\d+)|alertas(?:\/-?\d+)?|recomendaciones\/feedback|mantenimiento(?:\/-?\d+)?(?:\/(costos|fotos)(?:\/\d+)?)?|promociones(?:\/-?\d+)?|comisiones\/\d+\/liquidar|bandeja\/(?:\d+\/leida|leer-todas))$/.test(path);
 const queries=req.method==='POST'&&/^\/api\/(busqueda-semantica|servicios\/ia\/(chat|cotizar|descripcion))$/.test(path);
 return reads||writes||queries||(commercial&&['POST','PUT','DELETE'].includes(req.method))?from(inject(Sprint4Offline).request(req)):next(req);
};
