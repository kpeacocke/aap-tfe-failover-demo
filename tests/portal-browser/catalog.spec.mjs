import { test, expect } from '@playwright/test';
import { signIn } from './helpers.mjs';

test('operator OAuth login exposes exactly the two persisted custom templates', async ({ page }) => {
  const request = await signIn(page);
  const response = await request('/api/catalog/entities?filter=kind=template');
  expect(response.status()).toBe(200);
  const entities = await response.json();
  expect(entities.map(entity => entity.metadata.name).sort()).toEqual([
    'ww-demo-failover-custom', 'ww-demo-recovery-custom',
  ]);
  await expect(page.getByText('Datacentre Failover', { exact: true })).toBeVisible();
  await expect(page.getByText('Recover Datacentre', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Execution Environments', exact: true })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Git Repositories', exact: true })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Collections', exact: true })).toHaveCount(0);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.getByText('Datacentre Failover', { exact: true })).toBeVisible();
  const persisted = await request('/api/catalog/entities?filter=kind=template');
  expect((await persisted.json()).map(entity => entity.metadata.uid).sort())
    .toEqual(entities.map(entity => entity.metadata.uid).sort());
});
