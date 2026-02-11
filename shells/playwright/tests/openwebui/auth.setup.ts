import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('openwebui');
const authFile = path.join(__dirname, '..', '..', '.auth', 'openwebui.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/');

  // Open WebUI SPA redirects to /auth and takes a moment to render
  await expect(page.getByText('Sign in to Open WebUI')).toBeVisible();

  await page.getByRole('textbox', { name: 'Email' }).fill(svc.username);
  await page.getByRole('textbox', { name: 'Password' }).fill(svc.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('link', { name: 'New Chat' })).toBeVisible();

  await page.context().storageState({ path: authFile });
});
