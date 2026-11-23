import {test,expect} from '@playwright/test';
test.beforeEach(async({page})=>{
  await page.addInitScript(()=>{const user={ci:'market-test',id_rol:1,id_tenant:null,nombre:'SaaS',permisos:['UI:MENU_PROPIEDADES']};
    localStorage.setItem('user',JSON.stringify(user));localStorage.setItem('permissions',JSON.stringify(user.permisos));
    localStorage.setItem('token','test');localStorage.setItem('user_role','1');localStorage.setItem('selected_tenant','all');});
});

test('currency conversion works on a phone with cached rates offline',async({page,context})=>{
  await page.setViewportSize({width:375,height:812});
  let available=true;
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/raices-backend-n1yy.onrender.com/**',route=>{
    if(!available)return route.abort('internetdisconnected');
    if(new URL(route.request().url()).pathname==='/api/moneda')return route.fulfill({json:{base:'USD',tasas:{USD:'1',BOB:'6.96',EUR:'0.9',BRL:'5',CLP:'900',PEN:'3.7'},actualizado_en:new Date().toISOString(),proxima_actualizacion_unix:Date.now()/1000+86000,vencidas:false,fuente:'ExchangeRate-API',fuente_url:'https://www.exchangerate-api.com',aviso:'Tasa de prueba'}});
    return route.fulfill({json:[]});
  });
  await page.goto('/dashboard/moneda');
  await expect(page.getByRole('heading',{name:'696.00 BOB',exact:true})).toBeVisible();
  available=false;await context.setOffline(true);
  await page.getByRole('button',{name:'Actualizar tasas'}).click();
  await page.getByLabel('Monto a convertir').fill('150');
  await expect(page.getByRole('heading',{name:'1044.00 BOB',exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Invertir monedas'}).click();
  await expect(page.getByRole('heading',{name:'21.55 USD',exact:true})).toBeVisible();
  await page.getByText('Usar una tasa manual',{exact:true}).click();
  await page.getByLabel('Tasa manual',{exact:true}).fill('2');
  await expect(page.getByRole('heading',{name:'300.00 USD',exact:true})).toBeVisible();
  expect(await page.locator('.luxury-main').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBeTruthy();
  expect(errors).toEqual([]);
});

test('forecast distinguishes short real history from the explicit ML demo and exports CSV',async({page})=>{
  const series=(demo:boolean)=>({estado:demo?'calculado':'historial_insuficiente',eventos:demo?120:1,meses_entrenamiento:demo?24:1,
    modelo:'Ridge',mae_validacion:0.3,mae_base:1.1,mae_modelo_ml:0.3,meses_validacion:3,historial:[{mes:'2026-10',cantidad:1}],
    proyeccion:demo?Array.from({length:6},(_,i)=>({mes:`2027-0${i+1}`,cantidad:5+i})):[]});
  await page.route('**/raices-backend-n1yy.onrender.com/**',route=>{
    const url=new URL(route.request().url());
    if(url.pathname==='/api/predicciones'){
      expect(route.request().headers()['x-tenant-scope']).toBe('all');
      const demo=url.searchParams.get('modo')==='demo';
      return route.fulfill({json:{modo:demo?'demo':'real',alcance:'todas',generado_en:new Date().toISOString(),hasta:'2026-10',
        advertencia:demo?'Escenario sintético académico':'Historial insuficiente',definiciones:{ventas:'Contratos de venta',demanda:'Visitas no canceladas'},ventas:series(demo),demanda:series(demo)}});
    }
    return route.fulfill({json:[]});
  });
  await page.goto('/dashboard/predicciones');
  await expect(page.getByText(/Historial insuficiente. Agrega actividad/)).toHaveCount(2);
  await page.getByLabel('Datos del modelo').selectOption('demo');
  await expect(page.getByText('DEMOSTRACIÓN · DATOS SINTÉTICOS',{exact:true})).toBeVisible();
  await expect(page.getByText('Ridge',{exact:true})).toHaveCount(2);
  await page.getByLabel('Horizonte',{exact:true}).selectOption({label:'6 meses'});
  await expect(page.locator('.chart-label')).toHaveCount(12);
  const download=page.waitForEvent('download');await page.getByRole('button',{name:'Exportar proyección CSV'}).click();
  expect((await download).suggestedFilename()).toBe('predicciones.csv');
  await page.screenshot({path:'test-results/presentacion/predicciones.png',fullPage:true});
});
