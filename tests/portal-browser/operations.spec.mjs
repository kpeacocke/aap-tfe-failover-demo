import { test, expect } from '@playwright/test';
import { signIn } from './helpers.mjs';

async function expectTraffic(datacentre) {
  if (!process.env.HAPROXY_PUBLIC_IP) {
    throw new Error('HAPROXY_PUBLIC_IP is required to verify actual traffic after each Portal operation.');
  }
  const nodes = new Set();
  for (let sample = 0; sample < 8; sample += 1) {
    const response = await fetch(`http://${process.env.HAPROXY_PUBLIC_IP}/health`, {
      signal: AbortSignal.timeout(10_000),
    });
    expect(response.status).toBe(200);
    const health = await response.json();
    expect(health.status).toBe('healthy');
    expect(health.datacentre).toBe(datacentre);
    nodes.add(health.hostname);
  }
  expect([...nodes].sort()).toEqual([`${datacentre}-app-01`, `${datacentre}-app-02`]);
}

async function execute(page, request, operation, datacentre, reference) {
  const failover = operation === 'failover';
  const template = failover ? 'ww-demo-failover-custom' : 'ww-demo-recovery-custom';
  const step = failover ?
    'Execute the staged AAP failover workflow' : 'Execute the staged AAP recovery workflow';
  await page.goto(`/self-service/create/templates/default/${template}`, { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('textbox', { name: /token/i })).toHaveCount(0);
  await page.getByRole('button', {
    name: failover ? 'Target datacentre' : 'Recovered datacentre', exact: true,
  }).click();
  await page.getByRole('option', { name: datacentre, exact: true }).click();
  await page.getByRole('textbox', {
    name: failover ? 'Incident/change reference' : 'Original incident/change reference', exact: true,
  }).fill(reference);
  await page.getByRole('button', {
    name: failover ? 'Confirm traffic move' : 'Confirm recovered standby release', exact: true,
  }).click();
  await page.getByRole('option', { name: 'CONFIRM', exact: true }).click();
  await page.getByRole('button', { name: 'Next', exact: true }).click();
  await page.getByRole('button', { name: 'Create', exact: true }).click();
  await page.waitForURL(/\/self-service\/create\/tasks\/[^/]+$/, { waitUntil: 'domcontentloaded' });
  const taskId = new URL(page.url()).pathname.split('/').at(-1);
  console.log(`Portal ${operation} ${datacentre}: task ${taskId}, reference ${reference}`);
  await expect(page.getByText(step, { exact: true }).first()).toBeVisible();
  const deadline = Date.now() + 3_600_000;
  let completed;
  while (Date.now() < deadline) {
    const response = await request(`/api/scaffolder/v2/tasks/${taskId}`);
    expect(response.status()).toBe(200);
    const task = await response.json();
    if (['failed', 'cancelled'].includes(task.status)) {
      throw new Error(`Portal ${operation} task ${taskId} ${task.status}; retain incident guards and inspect its AAP execution.`);
    }
    if (task.status === 'completed') {
      completed = task;
      break;
    }
    await new Promise(resolve => setTimeout(resolve, 5_000));
  }
  if (!completed) {
    throw new Error(`Portal task ${taskId} exceeded its deadline; inspect AAP before attempting another operation.`);
  }
  expect(completed.spec.parameters.reference).toBe(reference);
  expect(Object.keys(completed.spec.parameters)).not.toContain('aapToken');
  expect(Object.keys(completed.spec.parameters)).not.toContain('token');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.getByText(step, { exact: true }).first()).toBeVisible();
}

test('Portal failover, standby recovery, switchback and final recovery preserve real traffic', async ({ page }) => {
  test.skip(process.env.DEMO_PORTAL_LIVE_OPERATIONS !== 'true',
    'Explicitly approve live traffic changes with DEMO_PORTAL_LIVE_OPERATIONS=true.');
  test.setTimeout(14_700_000);
  await expectTraffic('dc1');
  const request = await signIn(page);
  const reference = `portal-${Date.now()}`;
  await execute(page, request, 'failover', 'dc2', reference);
  await expectTraffic('dc2');
  await execute(page, request, 'recovery', 'dc1', reference);
  await expectTraffic('dc2');
  await execute(page, request, 'failover', 'dc1', `${reference}-back`);
  await expectTraffic('dc1');
  await execute(page, request, 'recovery', 'dc2', `${reference}-back`);
  await expectTraffic('dc1');
});
