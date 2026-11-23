import {test,expect} from '@playwright/test';

test.beforeEach(async({page})=>{
 await page.addInitScript(()=>{const u={ci:'crm',id_rol:1,id_tenant:null,nombre:'SaaS',permisos:['UI:MENU_PROPIEDADES']};for(const [k,v] of Object.entries({user:JSON.stringify(u),permissions:JSON.stringify(u.permisos),token:'test',user_role:'1',selected_tenant:'1'}))localStorage.setItem(k,v);});
});

test('phone Kanban creates and moves an opportunity offline then synchronizes once',async({page,context})=>{
 await page.setViewportSize({width:375,height:812});
 let available=true,syncs=0;const rows:any[]=[];const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/raices-backend-n1yy.onrender.com/**',async route=>{
  if(!available)return route.abort('internetdisconnected');
  const p=new URL(route.request().url()).pathname;
  if(p==='/api/oportunidades/opciones')return route.fulfill({json:{agentes:[],clientes:[],propiedades:[]}});
  if(p==='/api/oportunidades')return route.fulfill({json:rows});
  if(p==='/api/servicios/sync'){syncs++;const c=route.request().postDataJSON();if(c.metodo==='POST'){rows.push({...c.datos,id:10,version:1,inmobiliaria:'Raíces',historial:[]});return route.fulfill({json:rows[0]});}rows[0]={...rows[0],...c.datos,version:2};return route.fulfill({json:rows[0]});}
  return route.fulfill({json:[]});
 });
 await page.goto('/dashboard/oportunidades');
 await expect(page.getByRole('button',{name:'Nueva oportunidad'})).toBeEnabled();
 available=false;await context.setOffline(true);
 await page.getByRole('button',{name:'Nueva oportunidad'}).click();
 await page.getByLabel('Título de oportunidad',{exact:true}).fill('Casa para familia');
 await page.getByLabel('Contacto',{exact:true}).fill('María contacto');
 await page.getByRole('button',{name:'Guardar oportunidad'}).click();
 await expect(page.getByRole('heading',{name:'Casa para familia'})).toBeVisible();
 await page.getByLabel('Etapa de Casa para familia').selectOption('Visita');
 await expect(page.locator('.lane').filter({has:page.getByRole('heading',{name:'Visita · 1',exact:true})}).getByRole('heading',{name:'Casa para familia'})).toBeVisible();
 expect(syncs).toBe(0);
 available=true;await context.setOffline(false);await page.evaluate(()=>window.dispatchEvent(new Event('online')));
 await expect.poll(()=>syncs).toBe(2);
 expect(rows).toHaveLength(1);expect(rows[0].etapa).toBe('Visita');expect(rows[0].version).toBe(2);
 await page.getByRole('button',{name:'Actualizar',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Casa para familia'})).toBeVisible();
 expect(await page.locator('.luxury-main').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBeTruthy();expect(errors).toEqual([]);
});

test('workflow generates local offline tasks and records completion',async({page,context})=>{
 let available=true;
 await page.route('**/raices-backend-n1yy.onrender.com/**',route=>{
  if(!available)return route.abort('internetdisconnected');
  if(new URL(route.request().url()).pathname==='/api/oportunidades/opciones')return route.fulfill({json:{agentes:[],clientes:[],propiedades:[]}});
  return route.fulfill({json:[]});
 });
 await page.goto('/dashboard/workflow-ia');
 await expect(page.getByRole('button',{name:'Generar plan de seguimiento'})).toBeEnabled();
 available=false;await context.setOffline(true);
 await page.getByLabel('Consulta comercial').fill('Quiero visitar la casa hoy urgente');
 await page.getByRole('button',{name:'Generar plan de seguimiento'}).click();
 await expect(page.getByRole('heading',{name:'Visita · Alta'})).toBeVisible();
 await expect(page.getByRole('checkbox')).toHaveCount(3);
 await page.getByRole('checkbox').first().check();
 await expect(page.getByRole('checkbox').first()).toBeChecked();
 await expect(page.getByText(/Reglas locales; pendiente de sincronizar/)).toBeVisible();
});
