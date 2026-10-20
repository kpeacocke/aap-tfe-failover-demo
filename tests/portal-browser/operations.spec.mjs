import { test, expect } from '@playwright/test';
import { signIn, execute } from './helpers.mjs';

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
