import { expect } from '@playwright/test';
import { readFileSync } from 'node:fs';

export async function signIn(page) {
  const origin = new URL(process.env.DEMO_PORTAL_URL).origin;
  let authorization;
  page.on('request', request => {
    if (new URL(request.url()).origin === origin && request.headers().authorization) {
      authorization = request.headers().authorization;
    }
  });
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.getByRole('button', { name: 'Sign In', exact: true }).click();
  await expect(page).toHaveURL(url => url.origin === new URL(process.env.AAP_HOSTNAME).origin);
  await page.getByRole('textbox', { name: 'Username', exact: true }).fill('ww-demo-operator');
  const password = process.env.DEMO_OPERATOR_PASSWORD ||
    readFileSync(new URL('../../.local/aap-operator-password', import.meta.url), 'utf8').trim();
  await page.locator('input[type=password]').fill(password);
  await page.getByRole('button', { name: 'Log in', exact: true }).click();
  await page.waitForURL(
    url => url.origin === origin || url.pathname.startsWith('/o/authorize/'),
    { waitUntil: 'domcontentloaded' },
  );
  if (new URL(page.url()).origin !== origin) {
    await page.getByRole('button', { name: 'Authorize', exact: true }).click();
  }
  await page.waitForURL(url => url.origin === origin, { waitUntil: 'domcontentloaded' });
  await expect(page).toHaveURL(`${origin}/self-service/catalog`, { timeout: 60_000 });
  await expect(page.getByRole('link', { name: 'Templates', exact: true })).toBeVisible({ timeout: 60_000 });
  return async (path, options = {}) => {
    if (!authorization) {
      throw new Error('No authenticated Portal API request was observed after OAuth login.');
    }
    if (new URL(path, origin).origin !== origin) {
      throw new Error('Authenticated Portal requests must remain on the configured Portal origin.');
    }
    return page.request.fetch(path, {
      ...options,
      headers: { ...options.headers, Authorization: authorization },
    });
  };
}

export async function execute(page, request, operation, datacentre, reference) {
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
  await expect(page.getByText(step, { exact: true }).first()).toBeVisible({ timeout: 60_000 });
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
  await expect(page.getByText(step, { exact: true }).first()).toBeVisible({ timeout: 60_000 });
}
