import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('immich');
const authFile = path.join(__dirname, '..', '..', '.auth', 'immich.json');

setup('authenticate', async ({ page }) => {
  // Navigate directly to login page; the SPA redirect from / is slow in CI
  await page.goto('/auth/login');
  await expect(page.getByRole('heading', { name: 'Login' })).toBeVisible({ timeout: 15000 });

  await page.getByRole('textbox', { name: 'Email' }).fill(svc.username);
  await page.getByRole('textbox', { name: 'Password' }).fill(svc.password);
  await page.getByRole('button', { name: 'Login' }).click();

  await expect(page).toHaveURL(/\/photos/, { timeout: 30000 });

  await page.context().storageState({ path: authFile });
});
