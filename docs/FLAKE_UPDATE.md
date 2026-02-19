# Automated Flake Input Updates

## Overview

A Forgejo Actions workflow automatically updates all flake inputs daily, creating a PR that must pass CI before merging to `main`. Combined with the [auto-upgrade](AUTO_UPGRADE.md) system, this creates a fully automated pipeline: inputs are updated, CI validates the build, the PR merges, and fleet hosts pull the new configuration on their next upgrade cycle.

## Pipeline

```
06:00 UTC — Forgejo Actions runs nix flake update
    │
    ▼
Branch created: flake-update/YYYY-MM-DD-HHMMSS
    │
    ▼
PR opened against main → triggers nix-check CI
    │
    ├─ CI passes → PR auto-merges to main
    │                  │
    │                  ▼
    │              03:00-03:30 — Fleet hosts pull & apply via auto-upgrade
    │
    └─ CI fails → PR stays open for manual review
```

## How It Works

The workflow (`.forgejo/workflows/flake-update.yaml`) runs daily at 06:00 UTC (11pm MST):

1. **Clean up** — Deletes any leftover `flake-update/*` branches from previous runs
2. **Update inputs** — Runs `nix flake update` to fetch latest versions of all 22+ flake inputs (nixpkgs, home-manager, disko, agenix, etc.)
3. **Check for changes** — If `flake.lock` is unchanged, exits early (no PR created)
4. **Create branch** — `flake-update/YYYY-MM-DD-HHMMSS` (timestamp prevents collisions from manual re-runs)
5. **Push and create PR** — Opens a PR against `main` via Forgejo API
6. **Enable auto-merge** — Sets `merge_when_checks_succeed: true` so the PR merges automatically once CI passes

## CI Gate

The PR push triggers the `nix-check.yaml` workflow which:

- Runs `nix flake check` (evaluates all configurations, runs tests)
- Builds all host configurations (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel`)

Only if every host builds successfully does the PR auto-merge. A single build failure keeps the PR open.

## Token Setup

The workflow requires a Personal Access Token (PAT) because Forgejo's automatic `GITHUB_TOKEN` does not trigger other workflows. Without a PAT, the PR push would not start the CI pipeline.

### Create the token

1. Forgejo → top-right avatar → **Settings** → **Applications**
2. Under "Manage Access Tokens", name: `flake-update-bot`
3. Permissions: **repository** Read and Write
4. Click **Generate Token** and copy the value

### Add as repository secret

1. `nix-config` repository → **Settings** → **Actions** → **Secrets**
2. Click **Add Secret**
3. Name: `FLAKE_UPDATE_TOKEN`
4. Value: paste the token

## Schedule

| Time (UTC) | Time (MST) | Event |
|------------|------------|-------|
| 06:00 | 11:00pm | Flake update workflow runs |
| 06:02-06:15 | ~11:02pm | CI builds all hosts |
| 06:15-06:30 | ~11:15pm | PR auto-merges (if CI passes) |
| 10:00 (next day) | 03:00am | Fleet compute hosts pull from main |
| 10:30 (next day) | 03:30am | nas-01 pulls from main |

## Manual Trigger

Run the workflow on-demand from Forgejo UI:

1. Go to **Actions** tab in the repository
2. Select **Flake Update** workflow
3. Click **Run Workflow**

## Handling Failures

### CI fails on the PR

The PR stays open with a failed status. Review the CI logs to determine the cause:

```bash
just ci -s failure     # List recent failures
just ci logs <run-id>  # View logs
```

Common causes:
- A nixpkgs update introduces a build regression in an upstream package
- A breaking change in a flake input (e.g., home-manager module API change)

Fix options:
1. **Wait** — Close the PR. Tomorrow's run will try again with newer inputs
2. **Pin the input** — Add an override in `flake.nix` to pin the problematic input
3. **Fix forward** — Push a fix to `main`, then re-trigger the workflow

### Stale branches

Old `flake-update/*` branches are automatically cleaned up at the start of each run. No manual cleanup needed.

## Files

| File | Purpose |
|------|---------|
| `.forgejo/workflows/flake-update.yaml` | The update workflow |
| `.forgejo/workflows/nix-check.yaml` | CI pipeline triggered by the PR |
| `flake.lock` | Updated by the workflow |

## Related

- [Auto-Upgrade](AUTO_UPGRADE.md) — How fleet hosts pull and apply updates from `main`
