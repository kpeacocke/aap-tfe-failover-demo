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
  await page.goto('/self-service/catalog', { waitUntil: 'domcontentloaded' });
  await expect(page.getByRole('link', { name: 'Templates', exact: true })).toBeVisible({ timeout: 60_000 });
  return async (path, options = {}) => {
    if (!authorization) {
      throw new Error('No authenticated Portal API request was observed after OAuth login.');
    }
    return page.request.fetch(path, {
      ...options,
      headers: { ...options.headers, Authorization: authorization },
    });
  };
}
