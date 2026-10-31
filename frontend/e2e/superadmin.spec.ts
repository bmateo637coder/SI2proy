import { test, expect } from '@playwright/test';

test('superadministrador selecciona empresa, carga datos y exporta reportes', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => {
    localStorage.setItem('user', JSON.stringify({ ci: 'super', id_tenant: null, id_rol: 1,
      permisos: ['UI:MENU_CLIENTES', 'UI:MENU_PROPIEDADES', 'UI:MENU_USUARIOS', 'UI:MENU_CATALOGO'] }));
    localStorage.setItem('user_role', '1');
    localStorage.setItem('permissions', JSON.stringify(['UI:MENU_CLIENTES', 'UI:MENU_PROPIEDADES', 'UI:MENU_USUARIOS', 'UI:MENU_CATALOGO']));
    localStorage.setItem('token', 'test-token');
  });
  await page.route('**/admin/empresas', route => route.fulfill({ json: [{ id_tenant: 1, nombre: 'Empresa Norte' }, { id_tenant: 2, nombre: 'Empresa Sur' }] }));
  await page.route('**/modulo_inmuebles/**', route => {
    const tid = route.request().headers()['x-tenant-id'];
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith('/clientes')) return route.fulfill({ json: tid === '1' ? [{ id_cliente: 1, nombre: 'Cliente Norte', ci_usuario: '123', correo: 'norte@example.com' }] : [] });
    if (path.endsWith('/propiedades')) return route.fulfill({ json: tid === '1' ? [{ id_propiedad: 1, titulo: 'Casa Norte', precio: 120000,
      descripcion: 'Descripción conservada', estado: 'Disponible', tipo_operacion: 'Venta', id_propietario: 1, id_agente: 1, direccion: 'Centro' }] : [] });
    return route.fulfill({ json: [] });
  });
  await page.route('**/reportes/guardados', route => route.fulfill({ json: [] }));
  await page.route('**/reportes/generar', route => {
    expect(route.request().headers()['x-tenant-id']).toBe('1');
    expect(route.request().postDataJSON().filtros).toEqual([]);
    return route.fulfill({ json: { data: [{ titulo: 'Casa Norte', precio: 120000, estado: 'Disponible' }], truncado: false } });
  });
  await page.goto('/dashboard/clientes');
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Empresa Norte' });
  await expect(page.getByText('Cliente Norte', { exact: true })).toBeVisible();
  await page.goto('/dashboard/propiedades');
  await expect(page.getByRole('button', { name: 'Nueva Propiedad' })).toBeVisible();
  await page.getByRole('button', { name: 'Editar', exact: true }).click();
  await expect(page.locator('textarea[formcontrolname="descripcion"]')).toHaveValue('Descripción conservada');
  await page.goto('/dashboard/reportes');
  await page.getByRole('button', { name: /Generar Previsualización/ }).click();
  await expect(page.locator('table')).toContainText('Casa Norte');
  for (const format of ['Excel', 'PDF']) {
    const download = page.waitForEvent('download');
    await page.getByRole('button', { name: `Exportar ${format}`, exact: false }).click();
    expect((await download).suggestedFilename()).toMatch(format === 'PDF' ? /\.pdf$/ : /\.xlsx$/);
  }
  await page.goto('/dashboard/clientes');
  await page.getByRole('combobox', { name: 'Inmobiliaria activa' }).selectOption({ label: 'Empresa Sur' });
  await expect(page.getByText('No hay clientes registrados aún.', { exact: true })).toBeVisible();
  await expect(page.getByText('Cliente Norte', { exact: true })).not.toBeVisible();
  expect(errors).toEqual([]);
});

test('sesión vencida explica el error y solicita iniciar sesión otra vez', async ({ page }) => {
  await page.addInitScript(() => {
    if (!location.pathname.endsWith('/login')) {
      localStorage.setItem('user', JSON.stringify({ ci: 'admin', id_tenant: 1, id_rol: 2, permisos: ['UI:MENU_CLIENTES'] }));
      localStorage.setItem('permissions', JSON.stringify(['UI:MENU_CLIENTES']));
      localStorage.setItem('token', 'expired-token');
    }
  });
  await page.route('**/modulo_inmuebles/**', route => route.fulfill({ status: 401, json: { detail: 'Credenciales vencidas' } }));
  await page.goto('/dashboard/clientes');
  await expect(page).toHaveURL(/login\?reason=expired/);
  await expect(page.getByRole('alert')).toContainText('Tu sesión venció');
  expect(await page.evaluate(() => localStorage.getItem('token'))).toBeNull();
});
