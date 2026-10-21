import { defineConfig } from '@playwright/test';

if (!process.env.DEMO_PORTAL_URL) {
  throw new Error('Set DEMO_PORTAL_URL to the verified HTTPS Portal URL before running live browser tests.');
}
if (new URL(process.env.DEMO_PORTAL_URL).protocol !== 'https:') {
  throw new Error('Live Portal browser tests require HTTPS with certificate verification.');
}
if (process.env.DEMO_PORTAL_LIVE_OPERATIONS === 'true' && process.env.DEMO_LIVE_FAILURE_SMOKE === 'true') {
  throw new Error('Select only one live operation suite; failure smoke ends on DC2, while the four-operation suite requires DC1.');
}

export default defineConfig({
  testDir: '.',
  testMatch: ['access.spec.mjs', 'catalog.spec.mjs', 'operations.spec.mjs', 'failure-smoke.spec.mjs'],
  workers: 1,
  retries: 0,
  timeout: 180_000,
  expect: { timeout: 60_000 },
  reporter: 'list',
  use: {
    baseURL: process.env.DEMO_PORTAL_URL,
    navigationTimeout: 60_000,
    actionTimeout: 60_000,
    screenshot: 'only-on-failure',
    trace: 'off',
    video: 'off',
  },
});
