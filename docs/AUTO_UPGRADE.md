# Pull-Based Auto-Upgrade with Health Checks & Rollback

## Overview

The `services.clubcotton.auto-upgrade` NixOS module enables hosts to pull their configuration from Forgejo and safely apply it using a two-phase activation with health checks. If anything goes wrong, the host reboots to automatically restore the previous generation.

This replaces the push-based `just deploy-all` workflow for automated fleet upgrades.

## Core Safety Principle

NixOS has two activation modes:

- **`nixos-rebuild test`** — Activates the new config live but does **not** update the bootloader. A reboot returns to the previous generation automatically.
- **`nixos-rebuild switch`** — Activates **and** persists to the bootloader.

The module runs `test` first, validates the system is healthy, and only then runs `switch` to make it permanent. If anything breaks between `test` and the health check, a reboot is a guaranteed rollback with no special tooling needed.

## Upgrade Flow

```
Timer fires (e.g., 03:00 + random 0-15min)
    │
    ▼
Phase 1: nix build (fetch flake from Forgejo, build new system)
    │ FAIL → log error, exit (system unchanged)
    ▼
Phase 2: nixos-rebuild test (activate WITHOUT touching bootloader)
    │ FAIL → reboot → previous generation restored
    ▼
Phase 3: Health checks (retry loop, up to 120s)
    │  - ping gateway, DNS server
    │  - resolve domain names
    │  - systemd services active? (sshd, tailscaled, etc.)
    │  - TCP ports listening? (22, service-specific)
    │  - HTTP endpoints returning 2xx?
    │ FAIL → reboot → previous generation restored
    ▼
Phase 4: nixos-rebuild switch (persist to bootloader)
    │ FAIL → system running new config but bootloader not updated;
    │         next reboot returns to previous generation
    ▼
onSuccess hook (optional: trigger Playwright smoke tests via Forgejo API)
```

At no point can the system get stuck in a bad state. Before `switch`, a reboot always recovers. After `switch`, the system already passed health checks.

## Fleet Timing & Staggering

Hosts are grouped into tiers with increasing delay. Critical infrastructure upgrades last.

| Time | Tier | Hosts |
|------|------|-------|
| 03:00 + 0-15min random | Compute | nix-01, nix-02, nix-03, imac-01, imac-02, condo-01, natalya-01, frigate-host, octoprint |
| 03:30 + 0-15min random | Storage/Services | nas-01 |
| 03:00 + 0-15min random | Infrastructure | dns-01 |
| 05:00 | Verification | Forgejo runs Playwright smoke tests |

dns-01 upgrades ~1.5 hours after the first hosts. If the new config is broken in a way that local health checks can't catch, other hosts will have exhibited problems first.

The `randomizedDelaySec` prevents all hosts in a tier from hitting the Forgejo git server simultaneously and competing for the nix build cache.

## Trigger Model

**Pull-based polling** — each host has a systemd timer that fires on schedule. Hosts fetch the flake directly from Forgejo over Tailscale (public, no auth needed):

```
git+https://forgejo.bobtail-clownfish.ts.net/bcotton/nix-config?ref=main
```

No inbound SSH is required. Hosts can also be triggered manually:

```bash
systemctl start auto-upgrade.service
```

## Health Check Behavior

Health checks run in a **retry loop**, not a single pass. If a service like tailscaled takes 10 seconds to reconnect after activation, the check retries every 5 seconds for up to 120 seconds total. Only if checks still fail after the full timeout does it trigger a reboot.

Available check types:

| Check | Config key | What it does |
|-------|-----------|--------------|
| Ping | `pingTargets` | ICMP ping to IP addresses (gateway, DNS, etc.) |
| DNS | `dnsQueries` | Resolve domain names via `dig` |
| Services | `services` | `systemctl is-active` for named units |
| TCP ports | `tcpPorts` | Verify TCP ports are listening (host:port) |
| HTTP | `httpEndpoints` | `curl` URLs expecting HTTP 2xx |
| Custom | `extraScript` | Arbitrary shell commands (exit non-zero = fail) |

## Failure Modes & Recovery

| Failure | What happens | Recovery |
|---------|-------------|----------|
| Build fails | Nothing changes, exit 1 | Automatic — system untouched |
| `test` activation crashes services | Reboot triggered | Automatic — boots previous generation |
| Network breaks after `test` | Health checks fail → reboot | Automatic — boots previous generation |
| Services don't start after `test` | Health checks fail → reboot | Automatic — boots previous generation |
| `switch` fails after health checks pass | System running fine, bootloader not updated | Next reboot returns to previous generation |
| Boot failure on next reboot | Boot menu shows previous generations | Manual — select previous generation from boot menu |

## Configuration

### Minimal example

```nix
services.clubcotton.auto-upgrade = {
  enable = true;
  flake = "git+https://forgejo.bobtail-clownfish.ts.net/bcotton/nix-config?ref=main";
};
```

This uses defaults: upgrade at 04:00, check ping to 192.168.5.1, verify sshd and tailscaled are running, resolve google.com.

### Full example (dns-01)

```nix
services.clubcotton.auto-upgrade = {
  enable = true;
  flake = "git+https://forgejo.bobtail-clownfish.ts.net/bcotton/nix-config?ref=main";
  dates = "04:30";
  randomizedDelaySec = "0";  # No random delay for critical host
  healthChecks = {
    pingTargets = ["192.168.5.1" "192.168.5.42"];
    dnsQueries = ["google.com" "nas-01.lan"];
    services = ["sshd" "tailscaled" "technitium"];
    tcpPorts = [
      { port = 53; }
      { port = 5380; }
      { port = 22; }
    ];
    timeout = 180;  # Extra time for DNS to come up
  };
  onSuccess = ''
    # Trigger post-upgrade smoke tests (dns-01 is the last host)
    ${pkgs.curl}/bin/curl -sf -X POST \
      "https://forgejo.bobtail-clownfish.ts.net/api/v1/repos/bcotton/nix-config/actions/workflows/post-upgrade-smoke.yaml/dispatches" \
      -H "Authorization: token ''${FORGEJO_TOKEN}" \
      -d '{"ref":"main"}'
  '';
};
```

### All options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable pull-based auto-upgrade |
| `flake` | string | — | Flake URI to pull from |
| `dates` | string | `"04:00"` | Systemd calendar expression for timer |
| `randomizedDelaySec` | string | `"15min"` | Random delay for fleet staggering |
| `healthChecks.pingTargets` | list of string | `["192.168.5.1"]` | IPs to ping |
| `healthChecks.dnsQueries` | list of string | `["google.com"]` | Domains to resolve |
| `healthChecks.services` | list of string | `["sshd" "tailscaled"]` | Systemd units to check |
| `healthChecks.tcpPorts` | list of {host, port} | `[]` | TCP ports to verify |
| `healthChecks.httpEndpoints` | list of string | `[]` | URLs to check (HTTP 2xx) |
| `healthChecks.extraScript` | string | `""` | Custom health check commands |
| `healthChecks.timeout` | int | `120` | Max seconds for health check retries |
| `healthChecks.retryDelay` | int | `5` | Seconds between retries |
| `allowReboot` | bool | `true` | Auto-reboot on health check failure |
| `onSuccess` | string | `""` | Shell commands after successful upgrade |
| `onFailure` | string | `""` | Shell commands after failed upgrade |

## Operations

### Monitor upgrade status

```bash
# Watch a live upgrade
journalctl -u auto-upgrade.service -f

# Check last upgrade result
systemctl status auto-upgrade.service

# Check timer schedule
systemctl list-timers auto-upgrade.timer

# See upgrade history
journalctl -u auto-upgrade.service --since "7 days ago" --no-pager
```

### Manual trigger

```bash
systemctl start auto-upgrade.service
```

### Disable temporarily

```bash
# Prevent next scheduled run
systemctl stop auto-upgrade.timer

# Re-enable
systemctl start auto-upgrade.timer
```

## Post-Upgrade Smoke Tests

A Forgejo workflow (`.forgejo/workflows/post-upgrade-smoke.yaml`) runs the full Playwright smoke test suite:

- **Scheduled:** Daily at 05:00 (after the upgrade window)
- **On-demand:** Triggered via `workflow_dispatch` from a host's `onSuccess` hook

If smoke tests fail, they alert but don't rollback — hosts already passed their local health checks. Smoke test failures indicate service-level issues that need manual investigation.

## Files

| File | Purpose |
|------|---------|
| `modules/auto-upgrade/default.nix` | NixOS module definition |
| `.forgejo/workflows/post-upgrade-smoke.yaml` | Post-upgrade smoke test workflow |
| Per-host `default.nix` | Host-specific enable + health check config |

## Future Enhancements

- **systemd-boot boot counting:** When NixOS adds `boot.loader.systemd-boot.counters.enable`, this will provide automatic fallback if a generation fails to boot (kernel panic, filesystem issue). Currently requires manual boot menu selection.
- **Upgrade gating on CI status:** Only upgrade if the latest commit on `main` has a passing CI status, preventing upgrades of known-broken configs.
- **Fleet status dashboard:** Prometheus metrics from upgrade results for Grafana visualization.
