import { expect } from '@playwright/test';

export async function traffic(datacentre) {
  if (!process.env.HAPROXY_PUBLIC_IP) throw new Error('HAPROXY_PUBLIC_IP is required.');
  const nodes = new Set();
  for (let sample = 0; sample < 8; sample += 1) {
    const response = await fetch(`http://${process.env.HAPROXY_PUBLIC_IP}/health`, {
      signal: AbortSignal.timeout(10_000), redirect: 'error',
    });
    expect(response.status).toBe(200);
    const health = await response.json();
    expect(health.status).toBe('healthy');
    expect(health.datacentre).toBe(datacentre);
    nodes.add(health.hostname);
  }
  expect([...nodes].sort()).toEqual([`${datacentre}-app-01`, `${datacentre}-app-02`]);
}

export async function workspace(site) {
  const address = process.env.TFE_ADDRESS || 'https://app.terraform.io';
  if (new URL(address).origin !== 'https://app.terraform.io') {
    throw new Error('Live acceptance targets only HCP Terraform at https://app.terraform.io.');
  }
  const token = process.env.TFE_TOKEN || process.env.TF_TOKEN_app_terraform_io;
  const organization = process.env.HCP_TERRAFORM_ORGANIZATION;
  if (!token || !organization || !['shared', 'dc1', 'dc2'].includes(site)) {
    throw new Error('A Terraform token, organization and allowlisted workspace are required.');
  }
  const response = await fetch(
    `https://app.terraform.io/api/v2/organizations/${encodeURIComponent(organization)}/workspaces/ww-demo-${site}`,
    {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.api+json' },
      signal: AbortSignal.timeout(30_000), redirect: 'error',
    },
  );
  expect(response.status).toBe(200);
  const { data } = await response.json();
  expect(data.attributes.name).toBe(`ww-demo-${site}`);
  expect(data.attributes.locked).toEqual(expect.any(Boolean));
  return data;
}
