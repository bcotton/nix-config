import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('prowlarr');

test.describe('Prowlarr smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/login');
    await expect(page).toHaveTitle('Login - Prowlarr');
    await expect(page.getByRole('textbox', { name: 'User name is required' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Login' })).toBeVisible();

    await context.close();
  });

  test('indexers page loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Prowlarr/);
    await expect(page.getByRole('link', { name: 'Indexers' })).toBeVisible();
  });

  test('navigate to Search', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Search' }).click();
    await expect(page).toHaveURL(/\/search/);
  });

  test('navigate to History', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'History' }).click();
    await expect(page).toHaveURL(/\/history/);
  });

  test('search is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('textbox', { name: 'Search' })).toBeVisible();
  });
});
