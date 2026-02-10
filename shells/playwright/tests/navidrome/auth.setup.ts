import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');
const authFile = path.join(__dirname, '..', '..', '.auth', 'navidrome.json');

setup('authenticate', async ({ page }) => {
  page.on('crash', () => console.error('PAGE CRASHED'));
  page.on('close', () => console.log('page closed'));

  console.log('baseURL:', svc.url);
  try {
    const resp = await page.goto('/', { timeout: 20000 });
    console.log('goto result:', resp?.status(), 'url:', page.url());
  } catch (e: any) {
    console.error('goto THREW:', e.message?.split('\n')[0]);
  }
  await expect(page).toHaveURL(/.*#\/login/, { timeout: 15000 });

  await page.locator('input[name="username"]').fill(svc.username);
  await page.locator('input[name="password"]').fill(svc.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL(/.*#\/album/);

  await page.context().storageState({ path: authFile });
});
