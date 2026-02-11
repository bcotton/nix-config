import { test, expect } from '@playwright/test';
import { SERVICES } from '../services';

const svc = SERVICES['sabnzbd'];
const url = process.env[`${svc.envPrefix}_URL`] || svc.defaultUrl;

test.describe('SABnzbd smoke tests', () => {
  test('main page loads', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/SABnzbd/);
  });

  test('queue tab is visible', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('link', { name: /Queue/ })).toBeVisible();
  });

  test('history tab is visible', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('link', { name: /History/ })).toBeVisible();
  });

  test('navigate to config', async ({ page }) => {
    await page.goto('/config/');
    await expect(page).toHaveTitle('SABnzbd Config');
    await expect(page.getByRole('link', { name: 'General' })).toBeVisible();
  });

  test('config sections are accessible', async ({ page }) => {
    await page.goto('/config/');
    await expect(page.getByRole('link', { name: 'Servers' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Categories' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Scheduling' })).toBeVisible();
  });
});
