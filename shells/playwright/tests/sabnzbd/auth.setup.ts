import { test as setup, expect } from '@playwright/test';
import path from 'path';

const authFile = path.join(__dirname, '..', '..', '.auth', 'sabnzbd.json');

// SABnzbd has no login form (relies on Tailscale network auth).
// Just verify the page loads and save empty storage state.
setup('authenticate', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/SABnzbd/);
  await page.context().storageState({ path: authFile });
});
