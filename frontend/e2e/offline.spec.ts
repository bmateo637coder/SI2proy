import { test, expect } from '@playwright/test';

test('persiste offline, conserva fallos y separa cuentas', async ({ page, context }) => {
  let available = true;
  let received: any;
  await page.addInitScript(() => {
    if (!localStorage.getItem('user')) {
      localStorage.setItem('user', JSON.stringify({ ci: 'admin1', id_tenant: 1, id_rol: 2, permisos: [] }));
      localStorage.setItem('token', 'test-token');
    }
  });
  await page.route('**/api/offline/catalogo', route => route.fulfill({ json: {
    id_tenant: 1, ci_usuario: 'admin1', descargado_en: new Date().toISOString(),
    sucursales: [{ id_sucursal: 1, nombre: 'Casa matriz' }], clientes: [{ id_cliente: 1, nombre: 'Cliente demo' }],
    propiedades: [{ id_propiedad: 1, id_sucursal: 1, titulo: 'Casa para prueba', direccion: 'Centro',
      precio: '1000.00', version: 1, estado: 'Disponible', tipo_operacion: 'Venta' }]
  }}));
  await page.route('**/api/offline/sincronizar', route => {
    received = route.request().postDataJSON();
    return available ? route.fulfill({ json: { uuid: received.uuid, estado: 'confirmada', id_contrato: 1 } }) : route.abort('failed');
  });
  await page.route('**/modulo_inmuebles/**', route => route.fulfill({ json: [] }));
  await page.goto('/dashboard/offline');
  await page.getByRole('button', { name: 'Descargar catálogo y clientes' }).click();
  await expect(page.getByRole('heading', { name: 'Casa para prueba' })).toBeVisible();
  await page.locator('select').nth(1).selectOption({ label: 'Cliente demo' });
  await page.evaluate(() => navigator.serviceWorker.ready);
  await context.setOffline(true);
  await page.getByRole('button', { name: 'Registrar venta en efectivo' }).click();
  await expect(page.locator('table .badge')).toHaveText('local');
  await expect(page.locator('table')).toContainText('venta_contado');
  // La instalación y el shell cacheado permiten reiniciar sin red.
  await page.evaluate(() => navigator.serviceWorker.ready);
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Casa para prueba' })).toBeVisible();
  await expect(page.locator('table')).toContainText('venta_contado');
  available = false;
  await context.setOffline(false);
  await page.getByRole('button', { name: 'Sincronizar pendientes' }).click();
  await expect(page.locator('table')).toContainText('pendiente');
  const firstUUID = received.uuid;
  available = true;
  await page.getByRole('button', { name: 'Sincronizar pendientes' }).click();
  await expect(page.locator('table')).toContainText('confirmada');
  expect(received.uuid).toBe(firstUUID);
  await page.screenshot({ path: '../docs/capturas/offline.png', fullPage: true });
  await page.evaluate(() => localStorage.setItem('user', JSON.stringify({ ci: 'admin2', id_tenant: 2, id_rol: 2, permisos: [] })));
  await page.reload();
  await expect(page.locator('table')).not.toContainText('venta_contado');
  await expect(page.getByRole('heading', { name: 'Casa para prueba' })).not.toBeVisible();
});

test('manifest y recursos disponibles para instalar', async ({ page }) => {
  const response = await page.request.get('/manifest.webmanifest');
  const manifest = await response.json();
  expect(manifest.display).toBe('standalone');
  for (const icon of manifest.icons) expect((await page.request.get('/' + icon.src)).ok()).toBeTruthy();
  expect((await page.request.get('/sw.js')).ok()).toBeTruthy();
});

test('reporte dinámico se presenta y exporta en Excel y PDF', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('user', JSON.stringify({ ci: 'admin1', id_tenant: 1, id_rol: 2, permisos: [] }));
    localStorage.setItem('token', 'test-token');
  });
  await page.route('**/modulo_inmuebles/**', route => route.fulfill({ json: [] }));
  await page.route('**/api/analitica/reporte', route => route.fulfill({ json: {
    titulo: 'Contratos por sucursal', columnas: ['Sucursal', 'Contratos', 'Monto contratado'],
    filas: [['Casa matriz', 2, 180000], ['Oficina norte', 1, 90000]],
    generado_en: '2026-10-30', id_tenant: 1, filtros: { tipo: 'ventas_sucursal' },
    interprete: 'reglas_locales', resumen: '2 grupos encontrados en los datos de prueba.'
  }}));
  await page.goto('/dashboard/analitica');
  await page.getByRole('button', { name: 'Generar con lenguaje natural' }).click();
  await expect(page.locator('table')).toContainText('Casa matriz');
  await expect(page.locator('.bar')).toHaveCount(2);
  const excel = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Exportar Excel' }).click();
  expect((await excel).suggestedFilename()).toBe('reporte-raices.xlsx');
  const pdf = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Exportar PDF' }).click();
  expect((await pdf).suggestedFilename()).toBe('reporte-raices.pdf');
  await page.screenshot({ path: '../docs/capturas/analitica.png', fullPage: true });
});
