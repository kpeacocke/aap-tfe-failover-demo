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

test('failure reason is selectable without submitting an operation', async ({ page }) => {
  await signIn(page);
  await page.goto('/self-service/create/templates/default/ww-demo-failover-custom', {
    waitUntil: 'domcontentloaded',
  });
  await page.getByRole('button', { name: /^Reason/ }).click();
  await page.getByRole('option', { name: 'Site failure', exact: true }).click();
  await expect(page.getByRole('button', { name: /^Reason/ })).toContainText('Site failure');
  await page.goto('/self-service/catalog', { waitUntil: 'domcontentloaded' });
  await expect(page.getByText('Datacentre Failover', { exact: true })).toBeVisible();
});
