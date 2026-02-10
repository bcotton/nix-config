import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');
const authFile = path.join(__dirname, '..', '..', '.auth', 'navidrome.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/.*#\/login/, { timeout: 15000 });

  await page.locator('input[name="username"]').fill(svc.username);
  await page.locator('input[name="password"]').fill(svc.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL(/.*#\/album/, { timeout: 15000 });

  await page.context().storageState({ path: authFile });
});
