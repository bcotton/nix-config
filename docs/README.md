# Documentation Index

Comprehensive documentation for this NixOS/nix-darwin configuration repository.

## Quick Links

**Just getting started?**
- [Quick Start: Using the Cache](./QUICK_START_CACHE.md) - 2-minute setup for cache clients

**Common operations:**
- [Cache Operations Reference](./CACHE_OPERATIONS.md) - Command cheat sheet

## Core Documentation

### Build and Cache System

- **[Build and Cache Guide](./BUILD_AND_CACHE.md)** ⭐
  - Complete guide to the distributed build and binary cache system
  - Adding hosts as cache clients (NixOS and Darwin)
  - Adding hosts as builders
  - nixos-anywhere integration
  - Troubleshooting and performance tuning

- **[Quick Start Cache](./QUICK_START_CACHE.md)**
  - 2-minute setup guide for cache clients
  - Minimal configuration examples
  - Quick verification steps

- **[Cache Operations](./CACHE_OPERATIONS.md)**
  - Command reference for common operations
  - Monitoring and maintenance commands
  - Troubleshooting procedures
  - Emergency procedures

### Infrastructure

- **[ZFS Admin Guide](./ZFS_ADMIN_GUIDE.md)**
  - ZFS pool management
  - Dataset configuration
  - Snapshot and backup procedures
  - Performance tuning

- **[Remote Deployment](./REMOTE_DEPLOYMENT.md)**
  - nixos-rebuild SSH deployment
  - Alternative deployment methods
  - nixinate status and workarounds

### Architecture

- **[Flake Parts](./FLAKE_PARTS.md)**
  - Flake-parts architecture overview
  - Module organization
  - How to add new hosts and services

- **[Hyprland](./HYPRLAND.md)**
  - Hyprland Wayland compositor setup
  - Configuration details

## Additional Documentation

### Secrets Management

See also: [secrets/README-NIX-CACHE.md](../secrets/README-NIX-CACHE.md)
- Binary cache secrets
- SSH builder keys
- Secret regeneration procedures

### Service Documentation

Individual services may have additional documentation:
- `clubcotton/services/*/README.md` - Service-specific guides
- `modules/*/README.md` - Module documentation

## Repository Structure

```
.
├── clubcotton/          # Service configurations (media server stack)
│   └── services/        # Individual service modules
│       └── harmonia/    # Binary cache server
├── docs/                # This documentation
├── hosts/               # Host-specific configurations
│   ├── darwin/          # macOS hosts (nix-darwin)
│   └── nixos/           # Linux hosts (NixOS)
├── modules/             # Custom NixOS modules
│   ├── nix-builder/     # Build coordinator and cache client
│   ├── postgresql/      # PostgreSQL configuration
│   └── zfs/             # ZFS storage modules
├── secrets/             # Age-encrypted secrets
├── tests/               # NixOS integration tests
└── flake-modules/       # Flake-parts modules
```

## Getting Help

### Common Scenarios

**I want to...**

- **Use the binary cache** → [Quick Start Cache](./QUICK_START_CACHE.md)
- **Add a new builder** → [Build and Cache Guide](./BUILD_AND_CACHE.md#adding-hosts-as-builders)
- **Deploy a new host** → [Remote Deployment](./REMOTE_DEPLOYMENT.md)
- **Manage ZFS storage** → [ZFS Admin Guide](./ZFS_ADMIN_GUIDE.md)
- **Check cache status** → [Cache Operations](./CACHE_OPERATIONS.md#checking-cache-status)
- **Troubleshoot builds** → [Cache Operations](./CACHE_OPERATIONS.md#troubleshooting-commands)
- **Regenerate secrets** → [secrets/README-NIX-CACHE.md](../secrets/README-NIX-CACHE.md)

### System Overview

This repository manages a personal NixOS/nix-darwin configuration with:

**Infrastructure:**
- Multiple NixOS and Darwin hosts
- Distributed build system (4 builders)
- Binary cache server (Harmonia)
- ZFS storage with snapshots
- Tailscale VPN mesh network

**Services:**
- Media server stack (Jellyfin, Navidrome, *arr suite)
- Document management (Paperless, FreshRSS)
- Development tools (code-server, Hyprland)
- Infrastructure services (PostgreSQL, monitoring)

**Key Features:**
- Flake-based configuration with flake-parts
- Age-encrypted secrets management
- Automated snapshots and backups
- NixOS testing framework integration
- Remote deployment support

## Contributing

When adding new features or services:

1. Follow existing patterns (see [Flake Parts](./FLAKE_PARTS.md))
2. Add NixOS tests where appropriate
3. Document in relevant guides
4. Update this index if adding new documentation

## External Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [nix-darwin Manual](https://daiderd.com/nix-darwin/manual/)
- [Flake Parts](https://flake.parts/)
- [Harmonia](https://github.com/nix-community/harmonia)
