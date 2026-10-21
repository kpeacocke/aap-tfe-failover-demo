import { test, expect } from '@playwright/test';

test('DC1 rendered identity persists across reload and agrees with the real health endpoint', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle('Datacentre Failover Demo');
  await expect(page.getByRole('heading', { name: 'Datacentre Failover Demo' })).toBeVisible();
  await expect(page.getByText('STATUS: HEALTHY', { exact: true })).toBeVisible();
  const health = await page.request.get('/health');
  expect(health.status()).toBe(200);
  expect(await health.json()).toEqual({
    status: 'healthy', datacentre: 'dc1', hostname: 'dc1-app-01', version: '1.0.0',
  });
  await expect(page.locator('dd')).toHaveText(['DC1', 'dc1-app-01', '1.0.0']);
  await page.reload();
  await expect(page.locator('dd')).toHaveText(['DC1', 'dc1-app-01', '1.0.0']);
});

test('navigating between independently running site services shows the actual destination identity', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('dd').first()).toHaveText('DC1');
  await page.goto('http://127.0.0.1:18082/');
  await expect(page.locator('dd')).toHaveText(['DC2', 'dc2-app-01', '1.0.0']);
  const health = await page.request.get('http://127.0.0.1:18082/health');
  expect(health.status()).toBe(200);
  expect((await health.json()).datacentre).toBe('dc2');
  await page.reload();
  await expect(page.locator('dd').first()).toHaveText('DC2');
});

test('unknown routes return explicit 404 without corrupting later health or homepage navigation', async ({ page }) => {
  const response = await page.goto('/does-not-exist');
  expect(response.status()).toBe(404);
  expect(await response.json()).toEqual({ error: 'not found' });
  const health = await page.request.get('/health?probe=after-404');
  expect(health.status()).toBe(200);
  expect(health.headers()['content-type']).toContain('application/json');
  expect((await health.json()).status).toBe('healthy');
  await page.goto('/');
  await expect(page.getByText('STATUS: HEALTHY', { exact: true })).toBeVisible();
  await expect(page.locator('dd').first()).toHaveText('DC1');
});
