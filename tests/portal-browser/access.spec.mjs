import { test, expect } from '@playwright/test';
import { signIn } from './helpers.mjs';

test('anonymous and invalid credentials cannot access the catalog', async ({ page, request }) => {
  const response = await request.get('/api/catalog/entities?filter=kind=template');
  expect(response.status()).toBe(401);
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.getByRole('button', { name: 'Sign In', exact: true }).click();
  await page.getByRole('textbox', { name: 'Username', exact: true }).fill('ww-demo-nonexistent');
  await page.locator('input[type=password]').fill('invalid-demo-login');
  await page.getByRole('button', { name: 'Log in', exact: true }).click();
  await expect(page.getByText(/Invalid username or password/i)).toBeVisible();
  expect(new URL(page.url()).origin).not.toBe(new URL(process.env.DEMO_PORTAL_URL).origin);
  const stillDenied = await request.get('/api/catalog/entities?filter=kind=template');
  expect(stillDenied.status()).toBe(401);
});

test('operator cannot import catalog content or administer permissions', async ({ page }) => {
  const request = await signIn(page);
  await expect(request('https://example.invalid/')).rejects.toThrow(
    'Authenticated Portal requests must remain on the configured Portal origin.',
  );
  const before = await request('/api/catalog/entities?filter=kind=template');
  expect(before.status()).toBe(200);
  const beforeIds = (await before.json()).map(entity => entity.metadata.uid).sort();
  const policies = await request('/api/permission/policies');
  expect(policies.status()).toBe(403);
  const imported = await request('/api/catalog/locations?dryRun=true', {
    method: 'POST',
    data: {
      type: 'url',
      target: 'https://example.invalid/ww-demo-denied-template.yaml',
    },
  });
  expect(imported.status()).toBe(403);
  await page.goto('/self-service/catalog-import', { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('heading', { name: "404 We couldn't find that page", exact: true })).toBeVisible();
  const after = await request('/api/catalog/entities?filter=kind=template');
  expect((await after.json()).map(entity => entity.metadata.uid).sort()).toEqual(beforeIds);
});
