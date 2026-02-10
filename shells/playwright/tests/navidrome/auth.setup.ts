import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('navidrome');
const authFile = path.join(__dirname, '..', '..', '.auth', 'navidrome.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/.*#\/login/, { timeout: 15000 });

  // Wait for the login form to be ready
  await page.locator('input[name="username"]').waitFor({ timeout: 10000 });
  await page.locator('input[name="username"]').fill(svc.username);
  await page.locator('input[name="password"]').fill(svc.password);
  console.log('Filled credentials, username:', svc.username);

  const signInBtn = page.getByRole('button', { name: 'Sign in' });
  console.log('Sign in button visible:', await signInBtn.isVisible());

  // Monitor the login API response
  const responsePromise = page.waitForResponse(
    resp => resp.url().includes('/auth/login'),
    { timeout: 10000 }
  ).catch(e => { console.error('No login response:', e.message?.split('\n')[0]); return null; });

  await signInBtn.click();
  console.log('Clicked sign in');

  const loginResp = await responsePromise;
  if (loginResp) {
    console.log('Login API:', loginResp.status(), loginResp.url());
    if (loginResp.status() !== 200) {
      const body = await loginResp.text().catch(() => '(no body)');
      console.log('Login response body:', body.substring(0, 500));
    }
  }

  // Check for error messages on the page
  await page.waitForTimeout(2000);
  const notifications = await page.locator('[class*="notification"], [class*="error"], [class*="MuiSnackbar"], [role="alert"]').allTextContents().catch(() => []);
  if (notifications.length > 0) {
    console.log('Error notifications:', notifications);
  }
  console.log('URL after sign-in:', page.url());

  await expect(page).toHaveURL(/.*#\/album/, { timeout: 15000 });

  await page.context().storageState({ path: authFile });
});
