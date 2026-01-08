import { test, expect } from '@playwright/test';

test('basic navigation test', async ({ page }) => {
  await page.goto('https://google.com');
  await expect(page).toHaveTitle(/Google/);
});

test('page has search input', async ({ page }) => {
  await page.goto('https://google.com');
  await expect(page.locator('textarea[name="q"], input[name="q"]')).toBeVisible();
});
