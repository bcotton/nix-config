import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');

test.describe('Navidrome smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/');
    await expect(page).toHaveTitle('Navidrome');
    await expect(page).toHaveURL(/.*#\/login/);
    await expect(page.locator('input[name="username"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();

    await context.close();
  });

  test('albums are listed after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveURL(/.*#\/album/);
    await expect(page.locator('#react-admin-title')).toContainText('Albums');
    await expect(page.getByRole('listitem').first()).toBeVisible();
  });

  test('navigate to Artists', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('menuitem', { name: 'Artists' }).click();
    await expect(page.locator('#react-admin-title')).toContainText('Artists');
  });

  test('navigate to Songs', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('menuitem', { name: 'Songs' }).click();
    await expect(page.locator('#react-admin-title')).toContainText('Songs');
  });

  test('search box is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('textbox', { name: 'Search' })).toBeVisible();
  });
});
