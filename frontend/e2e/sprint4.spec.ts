import { test, expect } from '@playwright/test';

test('favoritos y búsqueda permanecen disponibles offline y sincronizan después',async({page,context})=>{
 const property={id_propiedad:1,id_tenant:1,titulo:'Casa del Centro',direccion:'Centro',precio:1000,tipo_operacion:'Venta',estado:'Disponible',imagenes:[],caracteristicas:[{nombre:'Cuartos',valor:'3'}]};
 let favorites:any[]=[], available=true;const receipts=new Map<string,any>();
 await page.addInitScript(()=>{
  const user={ci:'s4-test',id_rol:1,id_tenant:null,nombre:'SaaS',permisos:['UI:MENU_CATALOGO','UI:MENU_PROPIEDADES']};
  localStorage.setItem('user',JSON.stringify(user));localStorage.setItem('permissions',JSON.stringify(user.permisos));localStorage.setItem('token','s4-token');localStorage.setItem('user_role','1');localStorage.setItem('selected_tenant','1');
 });
 await page.route('**/raices-backend-n1yy.onrender.com/**',async route=>{
  if(!available)return route.abort('internetdisconnected');
  const path=new URL(route.request().url()).pathname;
  if(path==='/admin/empresas')return route.fulfill({json:[{id_tenant:1,nombre:'Empresa Centro'}]});
  if(path.endsWith('/propiedades/catalogo'))return route.fulfill({json:[property]});
  if(path==='/api/favoritos')return route.fulfill({json:favorites});
  if(path==='/api/busqueda-semantica')return route.fulfill({json:{resultados:[property],modo:'local',resumen:'Casa en venta'}});
  if(path==='/api/servicios/sync'){
   const c=route.request().postDataJSON();
   if(receipts.has(c.uuid))return route.fulfill({json:receipts.get(c.uuid)});
   if(c.ruta==='/api/favoritos/1')favorites=c.metodo==='POST'?[{id_propiedad:1,propiedad:property,disponible:true}]:[];
   const result={id_propiedad:1,favorito:c.metodo==='POST'};receipts.set(c.uuid,result);return route.fulfill({json:result});
  }
  if(path==='/api/recomendaciones')return route.fulfill({json:{basado_en:'novedades',recomendaciones:[]}});
  if(path==='/api/bandeja')return route.fulfill({json:{notificaciones:[],no_leidas:0}});
  if(path==='/api/mi-cuenta')return route.fulfill({json:{contratos:[],pagado:0,saldo:0}});
  return route.fulfill({json:[]});
 });
 await page.goto('/dashboard/servicios');
 await page.getByRole('textbox',{name:'Búsqueda natural'}).fill('Casa en venta hasta 1500');
 await page.getByRole('button',{name:'Buscar',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Casa del Centro'})).toBeVisible();
 await page.getByRole('button',{name:'Guardar favorito',exact:true}).click();
 await expect(page.getByRole('status')).toContainText('guardado');
 await page.getByRole('link',{name:'Favoritos y alertas',exact:true}).first().click();
 await expect(page.getByRole('heading',{name:'Favoritos y alertas',exact:true})).toBeVisible();
 await expect(page.locator('strong').filter({hasText:'Casa del Centro'})).toBeVisible();
 available=false;
 await context.setOffline(true);
 await page.getByRole('button',{name:'Quitar',exact:true}).click();
 await expect(page.getByText('Mis favoritos (0)',{exact:true})).toBeVisible();
 await expect(page.getByRole('status')).toContainText(/Pendiente de sincronización|datos de la última descarga/);
 await context.setOffline(false);
 available=true;
 await page.getByRole('link',{name:/Sincronizar servicios/}).click();
 await page.getByRole('button',{name:'Sincronizar ahora',exact:true}).click();
 await expect(page.getByText('No hay cambios pendientes.',{exact:true})).toBeVisible();
 expect(favorites).toHaveLength(0);
 expect(receipts.size).toBe(2);
});

test('el mapa y la gerencia tienen rutas web accesibles para SaaS',async({page})=>{
 await page.addInitScript(()=>{const user={ci:'root-s4',id_rol:1,id_tenant:null,permisos:['UI:MENU_PROPIEDADES']};localStorage.setItem('user',JSON.stringify(user));localStorage.setItem('permissions',JSON.stringify(user.permisos));localStorage.setItem('token','token');localStorage.setItem('selected_tenant','all');});
 await page.route('**/raices-backend-n1yy.onrender.com/**',route=>{
  const path=new URL(route.request().url()).pathname;
  if(path==='/api/analitica/zonas'){
   expect(route.request().headers()['x-tenant-scope']).toBe('all');
   return route.fulfill({json:{zonas:[{zona:'Centro',inmobiliaria:'Empresa Centro',id_tenant:1,inmuebles:3,disponibles:2,cierres:1,monto:1000,precio_m2:100,latitud:-17.78,longitud:-63.18,intensidad:1}],sin_coordenadas:[]}});
  }
  return route.fulfill({json:[]});
 });
 await page.goto('/dashboard/mapa-calor');
 await expect(page.getByRole('heading',{name:'Mapa de calor de zonas',exact:true})).toBeVisible();
 await expect(page.locator('table')).toContainText('Centro');
 await expect(page.locator('.leaflet-container')).toBeVisible();
});
