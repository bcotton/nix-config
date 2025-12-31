# Forgejo Deployment Guide

This document describes the Forgejo git forge installation and its distributed CI/CD runner infrastructure.

## Architecture Overview

### Components

1. **Forgejo Server (nas-01)**
   - Web UI and Git server
   - PostgreSQL database on ssdpool
   - Storage on `/ssdpool/local/forgejo`
   - Accessible via Tailscale and local network

2. **Forgejo Actions Runners (nix-01, nix-02, nix-03)**
   - 6 total runners (2 per host)
   - Docker-based job execution
   - NixOS and Ubuntu/Debian support

### Storage

- **Location:** `/ssdpool/local/forgejo` (ZFS filesystem on ssdpool)
- **Quota:** 200GB
- **Compression:** lz4
- **Components:**
  - `repositories/` - Git repositories
  - `lfs/` - Large File Storage objects
  - `data/` - Application data
  - `packages/` - Package registry storage

### Network Access

- **HTTP:** Port 3000
  - Local: `http://nas-01.lan:3000`
  - Tailscale: `http://forgejo:3000`
- **SSH (Git):** Port 2222
  - Local: `ssh://git@nas-01.lan:2222/user/repo.git`
  - Tailscale: `ssh://git@forgejo:2222/user/repo.git`

## Secrets Configuration

Before deployment, create the following secrets using agenix:

### Required Secrets

1. **forgejo-db-password** - PostgreSQL database password
   ```bash
   # Generate a secure password
   openssl rand -base64 32 > /tmp/forgejo-db-password

   # Encrypt with agenix
   agenix -e secrets/forgejo-db-password.age
   # Paste the password and save
   ```

2. **forgejo-runner-token** - Runner registration token

   **IMPORTANT:** This token must be generated from Forgejo's admin panel AFTER the first deployment.

   Initial deployment steps:
   ```bash
   # 1. Deploy Forgejo service first (without runners)
   just switch nas-01

   # 2. Access Forgejo web UI at http://nas-01.lan:3000
   # 3. Complete initial setup:
   #    - Create admin account
   #    - Log in as admin

   # 4. Generate runner token:
   #    - Go to Site Administration (top right menu)
   #    - Click "Actions" in left sidebar
   #    - Click "Runners"
   #    - Click "Create new Runner"
   #    - Copy the registration token

   # 5. Encrypt the token with agenix:
   agenix -e secrets/forgejo-runner-token.age
   # Paste the token and save

   # 6. Deploy runners:
   just switch nix-01
   just switch nix-02
   just switch nix-03
   ```

### Update secrets/secrets.nix

Add the following entries to `secrets/secrets.nix`:

```nix
"forgejo-db-password.age".publicKeys = allKeys;
"forgejo-runner-token.age".publicKeys = allKeys;
```

### Update age.secrets Configuration

Ensure each host has the appropriate secrets configured:

**nas-01 (hosts/nixos/nas-01/default.nix):**
```nix
age.secrets."forgejo-db-password" = {
  file = ../../../secrets/forgejo-db-password.age;
  mode = "440";
  owner = "forgejo";
  group = "postgres";
};
```

**nix-01, nix-02, nix-03 (hosts/nixos/nix-0X/default.nix):**
```nix
age.secrets."forgejo-runner-token" = {
  file = ../../../secrets/forgejo-runner-token.age;
  mode = "440";
  owner = "gitea-runner"; # NixOS uses gitea-runner for forgejo actions
  group = "gitea-runner";
};
```

## Deployment Procedure

### Prerequisites

- ZFS pool `ssdpool` must exist on nas-01
- PostgreSQL 16 or later
- Docker enabled on runner hosts (nix-01, nix-02, nix-03)
- Secrets configured as described above

### Initial Deployment

1. **Deploy Forgejo service on nas-01:**
   ```bash
   # Format configuration
   just fmt

   # Build to check for errors
   just build nas-01

   # Deploy
   just switch nas-01
   ```

2. **Complete Forgejo setup:**
   - Access http://nas-01.lan:3000
   - Complete initial installation wizard
   - Create admin account
   - Configure any additional settings

3. **Generate and configure runner token:**
   - Follow steps in "Secrets Configuration" section above
   - Generate token from Forgejo admin panel
   - Encrypt with agenix
   - Update secrets configuration

4. **Deploy runners on nix-01, nix-02, nix-03:**
   ```bash
   # Deploy all runners in parallel
   just deploy nix-01 &
   just deploy nix-02 &
   just deploy nix-03 &
   wait

   # Or deploy sequentially
   just switch nix-01
   just switch nix-02
   just switch nix-03
   ```

5. **Verify runner registration:**
   - Go to Forgejo Admin → Actions → Runners
   - Verify 6 runners are registered and online:
     - nix-01-runner-1
     - nix-01-runner-2
     - nix-02-runner-1
     - nix-02-runner-2
     - nix-03-runner-1
     - nix-03-runner-2

### Updating Configuration

To update Forgejo or runner configuration:

```bash
# Update specific host
just switch nas-01

# Update all hosts
just deploy-all

# Update specific runner host
just switch nix-01
```

## Features

### Enabled Features

- **Git LFS:** Large file storage for binary assets
- **Actions:** GitHub Actions-compatible CI/CD
- **Package Registry:** Container, npm, Maven, PyPI, etc.
- **Built-in SSH:** Dedicated SSH server for git operations

### Disabled Features

- **Federation:** ActivityPub integration (can be enabled if needed)

## Runner Configuration

### Labels

Each runner supports the following job labels:

- `nixos` - NixOS environment with Nix available
- `ubuntu-latest` - Ubuntu environment (Debian Bookworm with Node 20)
- `debian-latest` - Debian environment (Debian Bookworm with Node 20)

### Capacity

- 2 parallel jobs per runner
- 4 parallel jobs per host (2 runners × 2 capacity)
- 12 total parallel jobs across all runners

### Example Workflow

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  test-nixos:
    runs-on: nixos
    steps:
      - uses: actions/checkout@v3
      - name: Build with Nix
        run: nix build

  test-ubuntu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: npm ci
      - name: Run tests
        run: npm test
```

## Maintenance

### Database Backups

The PostgreSQL database is automatically backed up:

- **Syncoid:** Replicates `ssdpool/local/database` to `backuppool`
- **Sanoid:** Creates snapshots for point-in-time recovery
- **Borgmatic:** Offsite backup to rsync.net (if configured)

### Repository Backups

Repositories are stored on `/ssdpool/local/forgejo/repositories`:

- ZFS snapshots provide point-in-time recovery
- Include in Sanoid configuration for automatic snapshots
- Consider adding to Borgmatic for offsite backup

### Monitoring

The following monitoring is recommended:

- Prometheus metrics from PostgreSQL
- Disk space monitoring for ssdpool
- Runner health monitoring
- Service uptime monitoring via Grafana

### Log Locations

- **Forgejo service:** `journalctl -u forgejo -f`
- **Runners:** `journalctl -u gitea-runner@nix-XX-X -f`
- **PostgreSQL:** `journalctl -u postgresql -f`

## Troubleshooting

### Forgejo won't start

1. Check database connection:
   ```bash
   psql -h localhost -U forgejo -d forgejo
   ```

2. Check permissions on ssdpool:
   ```bash
   ls -la /ssdpool/local/forgejo
   # Should be owned by forgejo:share
   ```

3. Check logs:
   ```bash
   journalctl -u forgejo -n 100
   ```

### Runners not connecting

1. Verify token is correct:
   ```bash
   # Check token file exists and is readable
   cat /run/agenix/forgejo-runner-token
   ```

2. Check Docker:
   ```bash
   docker ps
   systemctl status docker
   ```

3. Check runner logs:
   ```bash
   journalctl -u gitea-runner@nix-01-1 -f
   ```

4. Verify network connectivity:
   ```bash
   curl http://nas-01.lan:3000
   ```

### Jobs failing

1. Check runner labels match workflow requirements
2. Verify Docker images are accessible
3. Check runner capacity isn't exceeded
4. Review job logs in Forgejo web UI

## Security Considerations

### Authentication

- Registration is disabled by default
- All users must be created by admin
- Require sign-in to view repositories (configurable)

### Network Security

- SSH is on non-standard port 2222
- Firewall allows ports 3000 and 2222
- Tailscale provides encrypted external access
- Consider using HTTPS/TLS for production

### Runner Security

- Runners use Docker isolation
- `/nix` is mounted read-only
- Non-privileged containers
- Separate user accounts for each runner

## Performance Tuning

### Database

Current configuration uses PostgreSQL 16 with default settings. Consider:

- Adjusting `shared_buffers` based on workload
- Enabling connection pooling for high traffic
- Regular VACUUM and ANALYZE operations

### Storage

- ZFS compression (lz4) reduces space usage
- 200GB quota should handle most use cases
- Monitor usage: `zfs list ssdpool/local/forgejo`
- Adjust quota if needed: `zfs set quota=500G ssdpool/local/forgejo`

### Runners

- Increase capacity per runner for more parallel jobs
- Add more runner instances if needed
- Consider dedicated runners for specific labels
- Use local Nix cache (Harmonia on nas-01) for faster builds

## References

- [Forgejo Documentation](https://forgejo.org/docs/latest/)
- [Forgejo Actions](https://forgejo.org/docs/latest/user/actions/)
- [NixOS Forgejo Module](https://search.nixos.org/options?query=services.forgejo)
- [NixOS Actions Runner](https://search.nixos.org/options?query=services.gitea-actions-runner)
