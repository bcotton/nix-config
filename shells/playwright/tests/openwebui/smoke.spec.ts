import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('openwebui');

test.describe('Open WebUI smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/');
    await expect(page.getByText('Sign in to Open WebUI')).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Email' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();

    await context.close();
  });

  test('chat page loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('link', { name: 'New Chat' })).toBeVisible();
  });

  test('user profile menu is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Open User Profile Menu' })).toBeVisible();
  });

  test('search is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Search', exact: true })).toBeVisible();
  });

  test('navigate to Notes', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Notes' }).click();
    await expect(page).toHaveURL(/\/notes/);
  });
});
