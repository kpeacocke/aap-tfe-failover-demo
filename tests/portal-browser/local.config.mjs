import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './local',
  workers: 1,
  retries: 0,
  reporter: 'list',
  use: {
    baseURL: 'http://127.0.0.1:18081',
    trace: 'off',
    video: 'off',
    screenshot: 'only-on-failure',
  },
  webServer: ['dc1', 'dc2'].map((site, index) => ({
    command: 'python3 ../../application/app.py',
    url: `http://127.0.0.1:${18081 + index}/health`,
    reuseExistingServer: false,
    timeout: 30_000,
    env: {
      PORT: String(18081 + index),
      DEMO_DATACENTRE: site,
      DEMO_HOSTNAME: `${site}-app-01`,
      DEMO_VERSION: '1.0.0',
    },
  })),
});
