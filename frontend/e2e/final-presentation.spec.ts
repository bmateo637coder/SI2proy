import { test, expect } from '@playwright/test';

test.beforeEach(async ({page}) => {
  await page.addInitScript(() => {
    const user = {ci:'review',id_rol:1,id_tenant:null,nombre:'SaaS',permisos:['UI:MENU_CATALOGO','UI:MENU_PROPIEDADES']};
    localStorage.setItem('user',JSON.stringify(user)); localStorage.setItem('permissions',JSON.stringify(user.permisos));
    localStorage.setItem('token','review-token'); localStorage.setItem('selected_tenant','all'); localStorage.setItem('user_role','1');
  });
});

test('map fits a phone, ignores invalid locations and clears outdated AI analysis', async ({page}) => {
  await page.setViewportSize({width:375,height:812});
  const errors:string[]=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/raices-backend-n1yy.onrender.com/**', route => {
    const url = new URL(route.request().url());
    if (url.pathname === '/api/analitica/zonas') return route.fulfill({json:{zonas:[
      {zona:'Centro',inmobiliaria:'Raíces',inmuebles:3,cierres:2,monto:2000,precio_m2:100,latitud:-17.78,longitud:-63.18,intensidad:1},
      {zona:'Sin ubicación',inmobiliaria:'Horizonte',inmuebles:1,cierres:0,monto:0,precio_m2:null,latitud:200,longitud:400,intensidad:0},
    ],sin_coordenadas:['Sin ubicación'],resumen:url.searchParams.get('resumen_ia')==='true'?'Análisis de cierres anterior':'',modo_resumen:'local'}});
    return route.fulfill({json:[]});
  });
  await page.goto('/dashboard/mapa-calor');
  await expect(page.locator('table')).toContainText('Centro');
  await expect(page.locator('.leaflet-overlay-pane path')).toHaveCount(2);
  expect((await page.locator('.mapa').boundingBox())!.width).toBeGreaterThan(250);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth)).toBeTruthy();
  expect(await page.locator('.luxury-main').evaluate(el=>el.scrollWidth <= el.clientWidth)).toBeTruthy();
  await page.getByRole('button',{name:'Análisis con IA'}).click();
  await expect(page.getByText('Análisis de cierres anterior',{exact:true})).toBeVisible();
  await page.getByLabel('Métrica del mapa').selectOption('monto');
  await expect(page.getByText('Análisis de cierres anterior',{exact:true})).toHaveCount(0);
  await expect(page.getByRole('heading',{name:'Ranking por monto cerrado'})).toBeVisible();
  expect(errors).toEqual([]);
  await page.screenshot({path:'test-results/presentacion/mapa-telefono.png',fullPage:true});
  await page.getByRole('button',{name:'Abrir menú de navegación'}).click();
  await expect(page.getByRole('navigation',{name:'Navegación principal'})).toBeVisible();
  await page.getByRole('link',{name:'Catálogo',exact:true}).click();
  await expect(page).toHaveURL(/dashboard\/catalogo/);
  await expect(page.getByRole('navigation',{name:'Navegación principal'})).toBeHidden();
});

test('recommended property keeps its full description after catalog filtering', async ({page}) => {
  await page.setViewportSize({width:375,height:812});
  const property = {id_propiedad:1,id_tenant:1,titulo:'Casa Centro',direccion:'Centro',precio:1000,tipo_operacion:'Venta',estado:'Disponible',descripcion:'Descripción completa conservada',imagenes:[],caracteristicas:[]};
  await page.route('**/raices-backend-n1yy.onrender.com/**',route=> {
    const url = new URL(route.request().url());
    if (url.pathname.endsWith('/propiedades/catalogo')) return route.fulfill({json:url.searchParams.has('precio_min')?[]:[property]});
    if (url.pathname==='/api/ia/recomendar') return route.fulfill({json:{recomendaciones:[{id_propiedad:1,titulo:'Casa Centro',precio:1000}]}});
    return route.fulfill({json:[]});
  });
  await page.goto('/dashboard/catalogo');
  await expect(page.locator('.grid-catalogo')).toContainText('Casa Centro');
  await page.getByPlaceholder('$ 0',{exact:true}).fill('2000');
  await page.getByRole('button',{name:'Explorar',exact:true}).click();
  await expect(page.locator('.grid-catalogo')).not.toContainText('Casa Centro');
  await page.getByRole('heading',{name:'Casa Centro',exact:true}).click();
  const dialog = page.getByRole('dialog',{name:'Ficha del inmueble'});
  await expect(dialog.getByText('Descripción completa conservada',{exact:true})).toBeVisible();
  expect((await dialog.boundingBox())!.width).toBeLessThanOrEqual(375);
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
});

test('catalog reports failed requests and validates price ranges', async ({page}) => {
  await page.setViewportSize({width:375,height:812});
  await page.route('**/raices-backend-n1yy.onrender.com/**',route => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith('/propiedades/catalogo')) return route.fulfill({status:500,json:{detail:'Catálogo temporalmente no disponible'}});
    return route.fulfill({json:[]});
  });
  await page.goto('/dashboard/catalogo');
  await expect(page.locator('app-catalogo [role=alert]')).toBeVisible();
  await page.getByPlaceholder('$ 0',{exact:true}).fill('1000');
  // Filter labels predate accessible form associations: use their bound inputs.
  await page.locator('input[type=number]').nth(1).fill('100');
  await page.getByRole('button',{name:'Explorar',exact:true}).click();
  await expect(page.locator('app-catalogo [role=alert]')).toContainText('Revisa el rango de precio');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth)).toBeTruthy();
  expect(await page.locator('.luxury-main').evaluate(el=>el.scrollWidth <= el.clientWidth)).toBeTruthy();
  await page.screenshot({path:'test-results/presentacion/catalogo-telefono.png',fullPage:true});
});
