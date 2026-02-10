# Playwright Smoke Tests

Post-upgrade smoke tests for self-hosted services. Each service gets a login + functional check to verify it's alive after NixOS rebuilds.

## Running Tests

```bash
cd shells/playwright
nix develop --command bash -c 'npm ci && npm test'
```

Tests require credentials in `../../.env` (repo root) or `./env` (local override). The `.env` is gitignored; the source of truth is `secrets/smoke-test-creds.age` (agenix-encrypted).

## Adding a New Service

1. Add entry to `tests/services.ts`:
   ```typescript
   newservice: {
     name: 'New Service',
     envPrefix: 'NEWSERVICE',
     defaultUrl: 'https://newservice.bobtail-clownfish.ts.net',
   },
   ```

2. Create `tests/newservice/auth.setup.ts` — service-specific login flow:
   ```typescript
   import { test as setup, expect } from '@playwright/test';
   import path from 'path';
   import { getServiceConfig } from '../services';

   const svc = getServiceConfig('newservice');
   const authFile = path.join(__dirname, '..', '..', '.auth', 'newservice.json');

   setup('authenticate', async ({ page }) => {
     await page.goto('/');
     // ... service-specific login steps ...
     await page.context().storageState({ path: authFile });
   });
   ```

3. Create `tests/newservice/smoke.spec.ts` — smoke tests using `@playwright/test`.

4. Add credentials to `.env`:
   ```
   NEWSERVICE_USERNAME=smoketest
   NEWSERVICE_PASSWORD=...
   ```

5. That's it. `playwright.config.ts` dynamically generates setup + test projects from the `SERVICES` registry.

## Discovering UI Locators

Use `playwright-cli` to explore the service UI interactively and find the right locators:

```bash
playwright-cli open https://service.example.com
playwright-cli snapshot          # See element tree with refs
playwright-cli fill e16 "user"   # Fill by ref, shows generated Playwright code
playwright-cli click e23         # Click by ref, shows generated code
playwright-cli close
```

Copy the generated `getByRole()`/`getByTestId()` code into your test files.

**Tip:** For passwords with special characters (`!`, `$`), use a heredoc to avoid shell escaping:
```bash
playwright-cli run-code "$(cat <<'EOF'
async page => {
  await page.getByRole("textbox", { name: "Password" }).fill("p@ss!w0rd$");
}
EOF
)"
```

## Architecture

```
playwright.config.ts          # Generates per-service projects from SERVICES registry
tests/
  services.ts                 # Service registry + getServiceConfig() helper
  navidrome/
    auth.setup.ts             # Login flow (saves storageState)
    smoke.spec.ts             # Smoke tests (use saved auth)
  grafana/
    auth.setup.ts
    smoke.spec.ts
  jellyfin/
    auth.setup.ts
    smoke.spec.ts
```

- **Setup projects** (`setup-<service>`) run `auth.setup.ts` to log in and save browser state to `.auth/<service>.json`
- **Test projects** (`<service>`) depend on setup, reuse saved auth via `storageState`
- All services run in parallel

## Env Var Convention

Each service uses a `<PREFIX>_` namespace:

| Variable | Purpose |
|----------|---------|
| `<PREFIX>_URL` | Base URL (optional, has default in registry) |
| `<PREFIX>_USERNAME` | Login username (required) |
| `<PREFIX>_PASSWORD` | Login password (required) |

## CI

The Forgejo workflow (`.forgejo/workflows/playwright.yaml`) injects credentials from the `SMOKE_TEST_CREDS` Forgejo secret into `shells/playwright/.env` before running tests. The config loads `.env` from the local dir first, then falls back to repo root.

## Test Guidelines

- Each test should be a quick functional check, not exhaustive coverage
- Login page test should use a fresh context (`storageState: undefined`) to verify the unauthenticated view
- Prefer role-based locators (`getByRole`, `getByTestId`) over CSS selectors
- Don't modify data — tests should be read-only
