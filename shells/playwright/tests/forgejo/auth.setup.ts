import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('forgejo');
const authFile = path.join(__dirname, '..', '..', '.auth', 'forgejo.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/user/login');
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();

  await page.getByRole('textbox', { name: 'Username or email address' }).fill(svc.username);
  await page.getByRole('textbox', { name: 'Password' }).fill(svc.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveTitle(/Dashboard/, { timeout: 15000 });

  await page.context().storageState({ path: authFile });
});
