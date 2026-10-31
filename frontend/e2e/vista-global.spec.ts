import { test, expect } from '@playwright/test';

test('todas las inmobiliarias consolida, filtra, exporta y vuelve a una empresa', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.addInitScript(() => {
    localStorage.setItem('user', JSON.stringify({ ci: 'super', id_rol: 1, id_tenant: null, permisos: ['UI:MENU_CATALOGO'] }));
    localStorage.setItem('user_role', '1');
    localStorage.setItem('permissions', JSON.stringify(['UI:MENU_CATALOGO']));
    localStorage.setItem('token', 'test-token');
  });
  const companies = [{ id_tenant: 1, nombre: 'Empresa Norte' }, { id_tenant: 2, nombre: 'Empresa Sur' }];
  const counts = { propiedades: 1, clientes: 1, propietarios: 0, agentes: 0, contratos: 0, usuarios: 1, sucursales: 1 };
  await page.route('**/admin/empresas', r => r.fulfill({ json: companies }));
  await page.route('**/modulo_inmuebles/**', r => r.fulfill({ json: [] }));
  await page.route('**/api/ia/recomendar', r => r.fulfill({ json: { recomendaciones: [] } }));
  await page.route('**/admin/vista-global/**', r => {
    expect(r.request().headers()['x-tenant-id']).toBeUndefined();
    const url = new URL(r.request().url());
    if (url.pathname.endsWith('/resumen')) return r.fulfill({ json: { inmobiliarias: 2,
      empresas: companies.map(c => ({ ...c, activa: true, plan: 'basico', suscripcion: 'activa', conteos: counts })),
      totales: { ...counts, propiedades: 2, clientes: 2, usuarios: 2, sucursales: 2 } } });
    const data = companies.filter(c => !url.searchParams.get('id_tenant') || String(c.id_tenant) === url.searchParams.get('id_tenant'))
      .map(c => ({ id_tenant: c.id_tenant, inmobiliaria: c.nombre, titulo: `Casa ${c.nombre}`, direccion: 'Centro',
        precio: 125000, estado: 'Disponible', tipo_operacion: 'Venta', nombre: `Cliente ${c.nombre}`, ci: String(c.id_tenant), correo: 'demo@example.com', telefono: null, caracteristicas: [] }));
    return r.fulfill({ json: { data, total: data.length, limite: 50, offset: 0 } });
  });
  await page.goto('/dashboard/profile');
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Todas las inmobiliarias' });
  await expect(page).toHaveURL(/vista-global/);
  await expect(page.getByRole('heading', { name: 'Todas las inmobiliarias', exact: true })).toBeVisible();
  await expect(page.locator('tbody tr')).toHaveCount(2);
  await expect(page.locator('table')).toContainText('Casa Empresa Norte');
  await expect(page.locator('table')).toContainText('Casa Empresa Sur');
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Exportar resumen (CSV)' }).click();
  expect((await download).suggestedFilename()).toBe('resumen-inmobiliarias.csv');
  await page.reload();
  await expect(page.getByRole('combobox', { name: 'Inmobiliaria activa' }).locator('option:checked')).toHaveText('Todas las inmobiliarias');
  await page.getByRole('button', { name: 'Clientes', exact: true }).click();
  await expect(page.locator('table')).toContainText('Cliente Empresa Sur');
  await page.getByRole('combobox', { name: 'Inmobiliaria del listado' }).selectOption({ label: 'Empresa Sur' });
  await expect(page.locator('tbody tr')).toHaveCount(1);
  await expect(page.locator('table')).not.toContainText('Empresa Norte');
  await page.getByRole('link', { name: 'Catálogo', exact: true }).click();
  await expect(page).toHaveURL(/vista-global\?entidad=propiedades/);
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Empresa Norte' });
  await expect(page).toHaveURL(/dashboard\/catalogo/);
  await expect(page.getByRole('heading', { name: 'Descubre tu Próximo Hogar' })).toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('selected_tenant'))).toBe('1');
  expect(errors).toEqual([]);
});

test('una cuenta de inmobiliaria no accede a la vista global aunque altere la selección guardada', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('user', JSON.stringify({ ci: 'admin', id_rol: 2, id_tenant: 1, permisos: [] }));
    localStorage.setItem('permissions', '[]'); localStorage.setItem('user_role', '2');
    localStorage.setItem('token', 'test-token'); localStorage.setItem('selected_tenant', 'all');
  });
  await page.route('**/modulo_inmuebles/**', r => r.fulfill({ json: [] }));
  await page.goto('/dashboard/vista-global');
  await expect(page).toHaveURL(/dashboard\/profile/);
  await expect(page.getByRole('combobox', { name: 'Inmobiliaria activa' })).toHaveCount(0);
});
