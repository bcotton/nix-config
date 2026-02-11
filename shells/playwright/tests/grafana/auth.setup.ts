import { test as setup, expect } from '@playwright/test';
import path from 'path';
import { getServiceConfig } from '../services';

const svc = getServiceConfig('grafana');
const authFile = path.join(__dirname, '..', '..', '.auth', 'grafana.json');

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await expect(page).toHaveTitle('Grafana');

  await page.getByTestId('data-testid Username input field').fill(svc.username);
  await page.getByTestId('data-testid Password input field').fill(svc.password);
  await page.getByTestId('data-testid Login button').click();

  await expect(page).toHaveTitle(/Home - Dashboards - Grafana/);

  await page.context().storageState({ path: authFile });
});
