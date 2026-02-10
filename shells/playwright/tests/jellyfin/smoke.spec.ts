import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('jellyfin');

test.describe('Jellyfin smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/');
    await expect(page).toHaveTitle('Jellyfin');
    await expect(page.getByRole('heading', { name: 'Please sign in' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'User' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();

    await context.close();
  });

  test('home page loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveURL(/.*#\/home\.html/);
    await expect(page.getByRole('heading', { name: 'My Media' })).toBeVisible();
  });

  test('media libraries are listed', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'My Media' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Movies', exact: true }).first()).toBeVisible();
    await expect(page.getByRole('link', { name: 'Shows', exact: true }).first()).toBeVisible();
  });

  test('search is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Search' })).toBeVisible();
  });

  test('user menu shows logged-in user', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: svc.username })).toBeVisible();
  });
});
