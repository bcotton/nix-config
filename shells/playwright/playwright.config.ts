import { defineConfig, devices } from '@playwright/test';
import path from 'path';
import dotenv from 'dotenv';
import { SERVICES } from './tests/services';

// Load .env: prefer local (CI writes here), fall back to repo root (local dev)
const localEnv = path.resolve(__dirname, '.env');
const repoEnv = path.resolve(__dirname, '../../.env');
dotenv.config({ path: localEnv, quiet: true });
dotenv.config({ path: repoEnv, quiet: true });

// Generate per-service setup + test project pairs
const setupProjects = Object.entries(SERVICES).map(([key, svc]) => ({
  name: `setup-${key}`,
  testDir: `./tests/${key}`,
  testMatch: /auth\.setup\.ts/,
  use: {
    baseURL: process.env[`${svc.envPrefix}_URL`] || svc.defaultUrl,
    launchOptions: {
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-dbus',
      ],
    },
  },
}));

const testProjects = Object.entries(SERVICES).map(([key, svc]) => ({
  name: key,
  testDir: `./tests/${key}`,
  testMatch: /.*\.spec\.ts/,
  use: {
    ...devices['Desktop Chrome'],
    channel: 'chromium' as const,
    baseURL: process.env[`${svc.envPrefix}_URL`] || svc.defaultUrl,
    storageState: path.join(__dirname, '.auth', `${key}.json`),
    launchOptions: {
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-dbus',
      ],
    },
  },
  dependencies: [`setup-${key}`],
}));

export default defineConfig({
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['list']
  ],
  use: {
    trace: 'on-first-retry',
    ignoreHTTPSErrors: true,
  },
  projects: [...setupProjects, ...testProjects],
});
