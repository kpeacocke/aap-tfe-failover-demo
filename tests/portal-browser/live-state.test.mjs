import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { traffic, workspace } from './live-state.mjs';

const originalFetch = globalThis.fetch;
const originalEnv = { ...process.env };

beforeEach(() => {
  process.env.TFE_ADDRESS = 'https://app.terraform.io';
  process.env.TFE_TOKEN = 'fixture-token';
  process.env.HCP_TERRAFORM_ORGANIZATION = 'fixture-org';
  process.env.HAPROXY_PUBLIC_IP = '192.0.2.10';
});
afterEach(() => {
  globalThis.fetch = originalFetch;
  process.env = { ...originalEnv };
});

test('workspace read uses exact allowlisted URL, TLS, bearer auth and no redirects', async () => {
  globalThis.fetch = async (url, options) => {
    assert.equal(url, 'https://app.terraform.io/api/v2/organizations/fixture-org/workspaces/ww-demo-dc1');
    assert.equal(options.headers.Authorization, 'Bearer fixture-token');
    assert.equal(options.redirect, 'error');
    return Response.json({ data: { attributes: { name: 'ww-demo-dc1', locked: true } } });
  };
  assert.equal((await workspace('dc1')).attributes.locked, true);
});

test('invalid endpoint, workspace or missing token is rejected before any request', async () => {
  globalThis.fetch = async () => { assert.fail('Unsafe request was attempted.'); };
  await assert.rejects(workspace('foreign'));
  process.env.TFE_ADDRESS = 'https://example.invalid';
  await assert.rejects(workspace('dc1'));
  process.env.TFE_ADDRESS = 'https://app.terraform.io';
  delete process.env.TFE_TOKEN;
  delete process.env.TF_TOKEN_app_terraform_io;
  await assert.rejects(workspace('dc1'));
});

test('API authentication errors and malformed lock contracts cannot become successful state checks', async () => {
  globalThis.fetch = async () => new Response('', { status: 401 });
  await assert.rejects(workspace('dc1'));
  globalThis.fetch = async () => Response.json({ data: { attributes: { name: 'ww-demo-dc1', locked: 'false' } } });
  await assert.rejects(workspace('dc1'));
  globalThis.fetch = async () => Response.json({ data: { attributes: { name: 'unrelated', locked: false } } });
  await assert.rejects(workspace('dc1'));
});

test('traffic acceptance requires both healthy nodes in the requested datacentre', async () => {
  let calls = 0;
  globalThis.fetch = async (_url, options) => {
    assert.equal(options.redirect, 'error');
    calls += 1;
    return Response.json({
      status: 'healthy', datacentre: 'dc2', hostname: `dc2-app-0${calls % 2 + 1}`,
    });
  };
  await traffic('dc2');
  assert.equal(calls, 8);
  await assert.rejects(traffic('dc1'));
  globalThis.fetch = async () => Response.json({ status: 'healthy', datacentre: 'dc2', hostname: 'dc2-app-01' });
  await assert.rejects(traffic('dc2'));
});
