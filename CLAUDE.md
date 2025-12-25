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

**Note:** Nixinate apps are incompatible with the flake schema. See REMOTE_DEPLOYMENT.md for deployment alternatives.

```bash
# Recommended: Use nixos-rebuild with SSH
nixos-rebuild switch --flake .#hostname --target-host root@hostname.lan

just build-all               # Build all configurations locally
just build-host hostname     # Build specific host configuration
```

### Testing

```bash
just vm                      # Run NixOS VM
nix build '.#checks.x86_64-linux.postgresql'  # Run specific tests
```

## Architecture

### Flake-Parts Structure

This flake uses [flake-parts](https://flake.parts/) for modular flake organization:

- **Main flake.nix** (57 lines) - Minimal, imports flake-parts modules
- **flake-modules/** - Modular flake outputs:
  - `formatter.nix` - Alejandra formatter for all systems (via perSystem)
  - `packages.nix` - Custom packages (primp, gwtmux) available on all systems
  - `overlays.nix` - Overlay exports for external consumption
  - `checks.nix` - NixOS tests (x86_64-linux only)
  - `hosts.nix` - System builders and all host configurations

**Benefits:**
- 85% reduction in main flake.nix (390 → 57 lines)
- Automatic per-system handling via `perSystem`
- Clean separation of concerns
- Packages available on all 4 systems (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)

### Directory Structure

- `flake.nix` - Main flake configuration using flake-parts.lib.mkFlake
- `flake-modules/` - Flake-parts modules defining outputs
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

System builders are defined in `flake-modules/hosts.nix`:
- `darwinSystem` - macOS configurations with nix-darwin and Home Manager
- `nixosSystem` - Full NixOS configurations with all modules
- `nixosMinimalSystem` - Minimal NixOS for specialized hosts

All builders use `self.legacyPackages.${system}.localPackages` for custom packages.

### Service Architecture

Services are organized under `clubcotton/services/` with each having:
- `default.nix` - Main service configuration
- Optional test files for NixOS testing framework

The repository manages a comprehensive media server stack including:
- Media management (Jellyfin, Navidrome, Calibre-web)
- Download automation (*arr suite, SABnzbd)
- Monitoring (Prometheus, Grafana)
- Infrastructure services (PostgreSQL, networking, storage)

### Package Overlays

Two overlay files serve different purposes:

1. **flake-modules/overlays.nix** - Exports overlays as flake outputs for external consumption
   - `overlays.yq` - yq package overlay
   - `overlays.claude-code` - claude-code version pinning
   - `overlays.default` - Combined core overlays

2. **overlays.nix** - NixOS/Darwin module that conditionally applies overlays based on config
   - Core overlays: yq, beets, qmk, claude-code (always applied)
   - Conditional overlays: jellyfin, zfs smart-disk-monitoring, ctlptl, delta

Custom overlays are defined in `overlays/` directory:
- `claude-code.nix` - Pins claude-code version for consistent updates
- `delta.nix` - Adds themes.gitconfig to delta package
- `jellyfin.nix` - Enables VPL (Video Processing Library) for hardware acceleration
- `beets.nix`, `qmk.nix`, `yq.nix` - Other tool-specific overrides

To update a package version in an overlay:
1. Edit the version number in the overlay file
2. Update the source hash (use `nix-prefetch-url` or set to `lib.fakeHash` and build to get correct hash)
3. Update `npmDepsHash` if applicable (for npm packages)

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