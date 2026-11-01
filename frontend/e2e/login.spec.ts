import { test, expect } from '@playwright/test';

test('muestra credenciales inválidas al responder la API', async ({ page }) => {
  await page.route('**/login', route => route.request().method() === 'POST'
    ? route.fulfill({ status: 401, json: { detail: 'Credenciales inválidas' } })
    : route.continue());
  await page.goto('/login');
  await page.locator('#email').fill('prueba@example.com');
  await page.locator('#password').fill('incorrecta');
  await page.getByRole('button', { name: 'Ingresar al Portal' }).click();
  await expect(page.getByRole('alert')).toContainText('Credenciales inválidas');
});
