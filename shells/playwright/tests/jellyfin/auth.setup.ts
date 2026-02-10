import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('jellyfin');
const authFile = path.join(__dirname, '..', '..', '.auth', 'jellyfin.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/');

  // Jellyfin SPA takes a moment to render the login form
  await expect(page.getByRole('heading', { name: 'Please sign in' })).toBeVisible();

  await page.getByRole('textbox', { name: 'User' }).fill(svc.username);
  await page.getByRole('textbox', { name: 'Password' }).fill(svc.password);
  await page.getByRole('button', { name: 'Sign In' }).click();

  await expect(page).toHaveURL(/.*#\/home\.html/, { timeout: 15000 });

  await page.context().storageState({ path: authFile });
});
