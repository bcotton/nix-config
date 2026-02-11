import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('sonarr');
const authFile = path.join(__dirname, '..', '..', '.auth', 'sonarr.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await expect(page).toHaveTitle('Login - Sonarr');

  await page.getByRole('textbox', { name: 'User name is required' }).fill(svc.username);
  await page.getByRole('textbox', { name: 'Password' }).fill(svc.password);
  await page.getByRole('button', { name: 'Login' }).click();

  await expect(page).toHaveTitle('Sonarr');

  await page.context().storageState({ path: authFile });
});
