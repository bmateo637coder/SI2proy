import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './e2e', timeout: 60000, workers: 1,
  use: { baseURL: 'http://127.0.0.1:4173', headless: true, browserName: 'chromium', viewport: { width: 1440, height: 1200 } },
  webServer: { command: 'node scripts/serve-pwa.mjs', url: 'http://127.0.0.1:4173', reuseExistingServer: false },
});
