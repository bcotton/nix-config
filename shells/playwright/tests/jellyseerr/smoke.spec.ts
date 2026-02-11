import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('jellyseerr');

test.describe('Jellyseerr smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/login');
    await expect(page).toHaveTitle(/Sign In/);
    await expect(page.getByRole('heading', { name: 'Login with Jellyfin' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Username' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();

    await context.close();
  });

  test('discover page loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Discover/);
    await expect(page.getByRole('link', { name: 'Discover', exact: true })).toBeVisible();
  });

  test('navigate to Movies', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Movies', exact: true }).click();
    await expect(page).toHaveURL(/\/discover\/movies/);
  });

  test('navigate to Series', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Series', exact: true }).click();
    await expect(page).toHaveURL(/\/discover\/tv/);
  });

  test('search is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('searchbox', { name: 'Search' })).toBeVisible();
  });
});
