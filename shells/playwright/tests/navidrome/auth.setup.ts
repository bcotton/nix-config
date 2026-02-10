import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');
const authFile = path.join(__dirname, '..', '..', '.auth', 'navidrome.json');

setup('authenticate', async ({ page }) => {
  console.log('baseURL config:', svc.url);
  console.log('Navigating to /...');
  const response = await page.goto('/');
  console.log('goto response:', response?.status(), response?.url());
  console.log('page.url() after goto:', page.url());
  await expect(page).toHaveURL(/.*#\/login/);

  await page.locator('input[name="username"]').fill(svc.username);
  await page.locator('input[name="password"]').fill(svc.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL(/.*#\/album/);

  await page.context().storageState({ path: authFile });
});
