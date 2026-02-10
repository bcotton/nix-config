import { test, expect } from '@playwright/test';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('grafana');

test.describe('Grafana smoke tests', () => {
  test('login page loads', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    await page.goto('/login');
    await expect(page).toHaveTitle('Grafana');
    await expect(page.getByTestId('data-testid Username input field')).toBeVisible();
    await expect(page.getByTestId('data-testid Password input field')).toBeVisible();
    await expect(page.getByTestId('data-testid Login button')).toBeVisible();

    await context.close();
  });

  test('API health endpoint returns ok', async ({ browser }) => {
    const context = await browser.newContext({ storageState: undefined, baseURL: svc.url });
    const page = await context.newPage();

    const response = await page.goto('/api/health');
    expect(response?.status()).toBe(200);
    const body = await response?.json();
    expect(body.database).toBe('ok');

    await context.close();
  });

  test('home dashboard loads after login', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Grafana/);
    await expect(page.getByRole('heading', { name: 'Welcome to Grafana' })).toBeVisible();
  });

  test('navigate to Dashboards', async ({ page }) => {
    await page.goto('/');
    await page.getByTestId('data-testid navigation mega-menu').getByRole('link', { name: 'Dashboards' }).click();
    await expect(page).toHaveTitle(/Dashboards - Grafana/);
  });

  test('navigate to Alerting', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Alerting' }).click();
    await expect(page).toHaveTitle(/Alerting - Grafana/);
  });

  test('search is available', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Search...' })).toBeVisible();
  });
});
