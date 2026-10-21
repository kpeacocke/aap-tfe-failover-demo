import { test, expect } from '@playwright/test';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { signIn, execute } from './helpers.mjs';
import { traffic, workspace } from './live-state.mjs';

const root = fileURLToPath(new URL('../..', import.meta.url));

async function powerState(command) {
  await new Promise((resolve, reject) => {
    const child = spawn('bash', ['scripts/aap-configure.sh', command], {
      cwd: root, timeout: 1_200_000, stdio: 'inherit',
    });
    child.once('error', reject);
    child.once('exit', (code, signal) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} failed (${signal || code}); inspect administrator EC2 state. No automatic compensation, unlock or marker removal was attempted.`));
    });
  });
}

test('explicit failure smoke: stop DC1, Portal failover, quarantine, restore and standby recovery', async ({ page }) => {
  test.skip(process.env.DEMO_LIVE_FAILURE_SMOKE !== 'true',
    'Requires separate explicit approval with DEMO_LIVE_FAILURE_SMOKE=true.');
  test.setTimeout(8_400_000);
  await traffic('dc1');
  for (const site of ['shared', 'dc1', 'dc2']) {
    expect((await workspace(site)).attributes.locked).toBe(false);
  }
  const request = await signIn(page);
  const reference = `smoke-${Date.now()}`;
  await powerState('simulate-dc1');
  await expect.poll(async () => {
    const response = await fetch(`http://${process.env.HAPROXY_PUBLIC_IP}/health`, {
      signal: AbortSignal.timeout(10_000), redirect: 'error',
    });
    return response.status;
  }, { timeout: 60_000 }).toBe(503);
  await execute(page, request, 'failover', 'dc2', reference, 'Site failure');
  await traffic('dc2');
  const quarantined = await workspace('dc1');
  expect(quarantined.attributes.locked).toBe(true);
  expect(quarantined.attributes['locked-reason']).toBe(
    `Demo-managed datacentre quarantine - ${reference} - dc1`,
  );
  await powerState('restore-dc1');
  await execute(page, request, 'recovery', 'dc1', reference);
  await traffic('dc2');
  for (const site of ['shared', 'dc1', 'dc2']) {
    expect((await workspace(site)).attributes.locked).toBe(false);
  }
  console.log(`Failure smoke ${reference} complete: DC2 active, DC1 recovered standby; no switchback performed.`);
});
