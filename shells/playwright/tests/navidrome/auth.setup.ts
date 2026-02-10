import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');
const authFile = path.join(__dirname, '..', '..', '.auth', 'navidrome.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/.*#\/login/, { timeout: 15000 });

  // Wait for the login form to be ready
  await page.locator('input[name="username"]').waitFor({ timeout: 10000 });
  await page.locator('input[name="username"]').fill(svc.username);
  await page.locator('input[name="password"]').fill(svc.password);
  console.log('Filled credentials, username:', svc.username);

  const signInBtn = page.getByRole('button', { name: 'Sign in' });
  console.log('Sign in button visible:', await signInBtn.isVisible());
  await signInBtn.click();
  console.log('Clicked sign in');

  // Wait a moment then log URL for debugging
  await page.waitForTimeout(3000);
  console.log('URL after 3s:', page.url());

  await expect(page).toHaveURL(/.*#\/album/, { timeout: 15000 });

  await page.context().storageState({ path: authFile });
});
