import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('forgejo');

test.describe('Forgejo smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/user/login');
    await expect(page).toHaveTitle(/Sign in/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Username or email address' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();

    await context.close();
  });

  test('dashboard loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Dashboard/);
    await expect(page.getByRole('link', { name: 'Dashboard' })).toBeVisible();
  });

  test('navigate to Explore', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Explore', exact: true }).click();
    await expect(page).toHaveURL(/\/explore/);
  });

  test('navigate to Issues', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Issues' }).click();
    await expect(page).toHaveURL(/\/issues/);
  });

  test('navigate to Pull requests', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Pull requests' }).click();
    await expect(page).toHaveURL(/\/pulls/);
  });

  test('user menu shows logged-in user', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByLabel('Navigation bar').getByRole('img', { name: svc.username })).toBeVisible();
  });
});
