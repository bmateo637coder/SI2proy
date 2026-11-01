import { test, expect } from '@playwright/test';

test('Todas filtra cada pantalla y conserva la ruta al cambiar entre empresas', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  const permissions = ['UI:MENU_CATALOGO', 'UI:MENU_USUARIOS', 'UI:MENU_CLIENTES', 'UI:MENU_PROPIETARIOS', 'UI:MENU_AGENTES', 'UI:MENU_PROPIEDADES'];
  await page.addInitScript(permisos => {
    localStorage.setItem('user', JSON.stringify({ ci: 'super', id_rol: 1, id_tenant: null, permisos }));
    localStorage.setItem('permissions', JSON.stringify(permisos)); localStorage.setItem('user_role', '1'); localStorage.setItem('token', 'test-token');
  }, permissions);
  const companies = ['Raíces', 'Horizonte', 'Cúspide'].map((nombre, i) => ({ id_tenant: i + 1, nombre }));
  const properties = companies.map(c => ({ id_propiedad: c.id_tenant, id_tenant: c.id_tenant, inmobiliaria: c.nombre,
    titulo: `Casa de ${c.nombre}`, direccion: 'Centro', precio: 100000, tipo_operacion: 'Venta', estado: 'Disponible', imagenes: [], caracteristicas: [] }));
  const people = companies.map(c => ({ id_tenant: c.id_tenant, inmobiliaria: c.nombre, nombre: `Persona de ${c.nombre}`,
    ci_usuario: String(c.id_tenant), id_cliente: c.id_tenant, id_agente: c.id_tenant, id_propietario: c.id_tenant }));
  await page.route('**/admin/empresas', r => r.fulfill({ json: companies }));
  await page.route('**/api/ia/recomendar', r => r.fulfill({ json: { recomendaciones: [] } }));
  const filter = (r: any, rows: any[]) => r.request().headers()['x-tenant-scope'] === 'all' ? rows
    : rows.filter(row => String(row.id_tenant) === r.request().headers()['x-tenant-id']);
  await page.route('**/modulo_inmuebles/**', r => r.fulfill({ json: filter(r, r.request().url().includes('/propiedades') ? properties : people) }));
  await page.route('**/reportes/guardados', r => r.fulfill({ json: [] }));
  await page.route('**/reportes/generar', r => {
    const all = r.request().headers()['x-tenant-scope'] === 'all';
    return r.fulfill({ json: { data: filter(r, properties), columnas: [...(all ? ['inmobiliaria'] : []), 'titulo', 'precio', 'estado'] } });
  });
  await page.route('**/gestion_contractual/contratos', r => r.fulfill({ json: filter(r, properties).map(p => ({ ...p,
    id_contrato: p.id_propiedad, cliente: 'Cliente', propiedad: p.titulo, monto_total: 100000, saldo_pendiente: 0,
    cuotas_pagadas: 1, cuotas_totales: 1, pagos: [], tipo_contrato: 'Venta' })) }));
  await page.goto('/dashboard/catalogo');
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Todas las inmobiliarias' });
  await expect(page).toHaveURL(/dashboard\/catalogo/);
  await expect(page.locator('.grid-catalogo button')).toHaveCount(3);
  await expect(page.locator('.grid-catalogo')).toContainText('Casa de Horizonte');
  await expect(page.locator('.grid-catalogo')).toContainText('Casa de Cúspide');
  await page.getByRole('link', { name: /Reportes Dinámicos/ }).click();
  await expect(page).toHaveURL(/dashboard\/reportes/);
  await page.getByRole('button', { name: /Generar Previsualización/ }).click();
  await expect(page.locator('tbody tr')).toHaveCount(3);
  await expect(page.locator('thead')).toContainText('INMOBILIARIA');
  for (const format of ['PDF', 'Excel']) {
    const download = page.waitForEvent('download');
    await page.getByRole('button', { name: `Exportar ${format}`, exact: false }).click();
    expect(await (await download).failure()).toBeNull();
  }
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Horizonte' });
  await expect(page).toHaveURL(/dashboard\/reportes/);
  await page.getByRole('button', { name: /Generar Previsualización/ }).click();
  await expect(page.locator('tbody tr')).toHaveCount(1);
  await expect(page.locator('table')).not.toContainText('Casa de Cúspide');
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Todas las inmobiliarias' });
  await expect(page).toHaveURL(/dashboard\/reportes/);
  await page.getByRole('button', { name: /Generar Previsualización/ }).click();
  await expect(page.locator('tbody tr')).toHaveCount(3);
  await page.getByRole('link', { name: 'Propiedades', exact: true }).click();
  await expect(page.locator('tbody tr')).toHaveCount(3);
  await expect(page.locator('table')).toContainText('Horizonte');
  await expect(page.getByRole('button', { name: 'Nueva Propiedad' })).toHaveCount(0);
  for (const label of ['Clientes', 'Agentes', 'Propietarios']) {
    await page.getByRole('link', { name: label, exact: true }).click();
    await expect(page.getByText('Persona de Cúspide', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Eliminar', exact: true })).toHaveCount(0);
  }
  await page.getByRole('link', { name: 'Contratos y Pagos', exact: true }).click();
  await expect(page.locator('tbody tr')).toHaveCount(3);
  await expect(page.locator('table')).toContainText('Horizonte');
  await page.reload();
  await expect(page.getByRole('combobox', { name: 'Inmobiliaria activa' }).locator('option:checked')).toHaveText('Todas las inmobiliarias');
  await expect(page).toHaveURL(/dashboard\/contratos/);
  expect(errors).toEqual([]);
});
