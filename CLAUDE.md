# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal NixOS/nix-darwin configuration repository managing multiple machines and services. The configuration uses Nix flakes and supports both macOS (via nix-darwin) and Linux (via NixOS) systems.

## Common Commands

### Building and Switching Configurations

Whenever you are running `nix` commands using bash, and you have a `#` character in the command line, e.g.  .#darwinConfigurations.bobs-laptop.system, you need to surround the argument with the # in quotes, either single or double.

**macOS (nix-darwin):**
```bash
just build [target_host]     # Build without switching
just switch [target_host]    # Build and switch to new config
just trace [target_host]     # Build with --show-trace for debugging
```

**Linux (NixOS):**
```bash
just build [target_host]     # Build (includes nix fmt)
just switch [target_host]    # Build and switch with sudo
just trace [target_host]     # Build with --show-trace for debugging
```

### Development Commands

```bash
just fmt                     # Format all nix files
just check                   # Run nix flake check (with nixinate commented out)
just repl                    # Start nix repl with flake loaded
just update                  # Update all flake inputs
just gc [generations]        # Garbage collect (default: 5d)
```

### Remote Deployment

```bash
just nixinate hostname       # Deploy to specific host via nixinate
just nix-all                 # Deploy to all configured hosts
just build-all               # Build all configurations locally
just build-host hostname     # Build specific host configuration
```

### Testing

```bash
just vm                      # Run NixOS VM
nix build '.#checks.x86_64-linux.postgresql'  # Run specific tests
```

## Architecture

### Directory Structure

- `flake.nix` - Main flake configuration defining all systems and modules
- `hosts/` - Host-specific configurations
  - `common/` - Shared configurations (packages, darwin/nixos common)
  - `darwin/` - macOS host configurations
  - `nixos/` - Linux host configurations
- `home/` - Home Manager user configurations
- `modules/` - Custom NixOS modules for services
- `clubcotton/` - Service configurations (media server stack, etc.)
- `secrets/` - Age-encrypted secrets
- `users/` - User account definitions
- `overlays/` - Nix package overlays
- `pkgs/` - Custom package definitions
- `terraform/` - Infrastructure as code for container deployment

### Key System Functions

The flake defines three main system builders:
- `darwinSystem` - macOS configurations with nix-darwin and Home Manager
- `nixosSystem` - Full NixOS configurations with all modules
- `nixosMinimalSystem` - Minimal NixOS for specialized hosts

### Service Architecture

Services are organized under `clubcotton/services/` with each having:
- `default.nix` - Main service configuration
- Optional test files for NixOS testing framework

The repository manages a comprehensive media server stack including:
- Media management (Jellyfin, Navidrome, Calibre-web)
- Download automation (*arr suite, SABnzbd)
- Monitoring (Prometheus, Grafana)
- Infrastructure services (PostgreSQL, networking, storage)

### Secrets Management

Uses `agenix` for secret encryption. Secrets are defined in `secrets/secrets.nix` and encrypted files stored in `secrets/` directory.

### Remote Deployment

Uses `nixinate` for remote deployment with automatic host detection based on Tailscale configuration. Builds can be performed locally or remotely based on configuration.

## Development Notes

- All configurations support both stable and unstable nixpkgs channels
- Home Manager is integrated for user-level configurations  
- ZFS storage configurations available in `modules/zfs/`
- PostgreSQL integration testing framework in `tests/`
- Uses `alejandra` for nix code formatting
- Justfile provides cross-platform commands that detect current hostname automatically