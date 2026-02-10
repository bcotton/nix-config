import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('sonarr');

test.describe('Sonarr smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/login');
    await expect(page).toHaveTitle('Login - Sonarr');
    await expect(page.getByRole('textbox', { name: 'User name is required' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Login' })).toBeVisible();

    await context.close();
  });

  test('series page loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle('Sonarr');
    await expect(page.getByRole('link', { name: 'Series' })).toBeVisible();
  });

  test('navigate to Calendar', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Calendar' }).click();
    await expect(page).toHaveURL(/\/calendar/);
  });

  test('navigate to Wanted', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Wanted' }).click();
    await expect(page).toHaveURL(/\/wanted/);
  });

  test('search is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('textbox', { name: 'Search' })).toBeVisible();
  });
});
