import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');
const authFile = path.join(__dirname, '..', '..', '.auth', 'navidrome.json');

setup('authenticate', async ({ context }) => {
  // Use context fixture directly so we can create fresh pages after crashes.
  // Navidrome's SPA causes a transient Chromium renderer crash in containers
  // that recovers after a few seconds — but @playwright/test assertions don't
  // survive the crash, so we create a new page after the renderer stabilizes.
  let page = await context.newPage();

  page.on('crash', () => console.error('PAGE CRASHED'));

  console.log('baseURL:', svc.url);
  try {
    const resp = await page.goto(svc.url + '/', { timeout: 20000 });
    console.log('goto result:', resp?.status(), 'url:', page.url());
  } catch (e: any) {
    console.error('goto THREW:', e.message?.split('\n')[0]);
  }

  // Wait for potential renderer crash recovery
  await new Promise(resolve => setTimeout(resolve, 5000));
  console.log('After 5s wait, page.url():', page.url());

  // If page crashed, create a fresh page — the renderer has recovered by now
  let url: string;
  try {
    url = page.url();
    // Verify the page is actually responsive
    await page.title();
  } catch {
    console.log('Page unresponsive after crash, creating new page...');
    await page.close().catch(() => {});
    page = await context.newPage();
    await page.goto(svc.url + '/', { timeout: 20000 });
    await new Promise(resolve => setTimeout(resolve, 5000));
    url = page.url();
  }

  console.log('Proceeding with url:', url);
  await expect(page).toHaveURL(/.*#\/login/, { timeout: 15000 });

  await page.locator('input[name="username"]').fill(svc.username);
  await page.locator('input[name="password"]').fill(svc.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL(/.*#\/album/);

  await page.context().storageState({ path: authFile });
});
