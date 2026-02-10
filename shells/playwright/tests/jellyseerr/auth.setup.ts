import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('jellyseerr');
const authFile = path.join(__dirname, '..', '..', '.auth', 'jellyseerr.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await expect(page.getByRole('heading', { name: 'Login with Jellyfin' })).toBeVisible({ timeout: 15000 });

  await page.getByRole('textbox', { name: 'Username' }).fill(svc.username);
  await page.getByRole('textbox', { name: 'Password' }).fill(svc.password);
  await page.getByRole('button', { name: 'Sign In' }).click();

  await expect(page).toHaveTitle(/Discover/, { timeout: 15000 });

  await page.context().storageState({ path: authFile });
});
