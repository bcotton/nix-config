import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('immich');

test.describe('Immich smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/');
    await expect(page).toHaveTitle(/Login.*Immich/);
    await expect(page.getByRole('heading', { name: 'Login' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Email' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Login' })).toBeVisible();

    await context.close();
  });

  test('photos page loads after login', async ({ page }) => {
    await page.goto('/photos');
    await expect(page).toHaveTitle(/Photos.*Immich/);
    await expect(page.getByRole('link', { name: 'Photos' })).toBeVisible();
  });

  test('navigate to Explore', async ({ page }) => {
    await page.goto('/photos');
    await page.getByRole('link', { name: 'Explore' }).click();
    await expect(page).toHaveURL(/\/explore/);
  });

  test('navigate to Sharing', async ({ page }) => {
    await page.goto('/photos');
    await page.getByRole('link', { name: 'Sharing' }).click();
    await expect(page).toHaveURL(/\/sharing/);
  });

  test('search is available', async ({ page }) => {
    await page.goto('/photos');
    await expect(page.getByRole('combobox', { name: 'Search your photos' })).toBeVisible();
  });

  test('user menu shows logged-in user', async ({ page }) => {
    await page.goto('/photos');
    await expect(page.getByRole('button', { name: svc.username })).toBeVisible();
  });
});
