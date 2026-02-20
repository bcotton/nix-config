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
just check                   # Run nix flake check
just repl                    # Start nix repl with flake loaded
just update                  # Update all flake inputs
just gc [generations]        # Garbage collect (default: 5d)
```

### Remote Deployment

Remote deployment uses nixos-rebuild with SSH. See REMOTE_DEPLOYMENT.md for additional alternatives.

```bash
just deploy hostname         # Deploy to specific remote host via SSH
just deploy-all              # Deploy to all NixOS hosts (excludes admin)
just build-all               # Build all configurations locally
just build-host hostname     # Build specific host configuration
```

**Manual deployment:**
```bash
nixos-rebuild switch --flake .#hostname \
  --target-host root@hostname.lan \
  --build-host localhost
```

### CI / Forgejo Actions

```bash
just ci                      # List recent Forgejo Action runs
just ci -n 20                # List last 20 runs
just ci -s failure           # Show only failed runs
just ci -b main              # Filter by branch
just ci show 401             # Show details of run #401
just ci logs 401             # Show logs for run #401
just ci logs 401 1           # Show logs for job index 1 of run #401
```

The script reads your API token from the `tea` CLI config at `~/.config/tea/config.yml`.
Override with `FORGEJO_TOKEN` env var if needed.

### Testing

```bash
nix build '.#checks.x86_64-linux.postgresql'  # Run specific tests
```

**Important: When creating or debugging tests, force local execution to simplify iteration:**
```bash
# Disable distributed builders to run tests locally
nix flake check --option builders ''
nix build '.#checks.x86_64-linux.postgresql' --option builders ''

# Or for just check command:
just check  # (Note: consider adding a 'just check-local' command)
```

Running tests locally during development avoids:
- SSH connection overhead and potential failures
- Complexity of debugging across remote machines
- Build cache inconsistencies between builders
- Longer feedback loops during rapid iteration

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

**Important: Claude should NOT attempt to create, edit, or configure agenix secrets.**

When working with features that require secrets:
1. Add the secret definition to `secrets/secrets.nix` (this is safe - just metadata)
2. Reference the secret in your configuration using `config.age.secrets.<name>.path`
3. Leave clear instructions for the user to create/edit the actual encrypted secret file using `agenix -e <secret-name>.age`
4. Document what content/format the secret file should contain

Example instructions to provide:
```bash
# After this configuration is applied, create the secret:
agenix -e new-secret.age
# Then add the required content (e.g., password, API key, etc.)
```

See `secrets/README-NIX-CACHE.md` for an example of proper secret documentation.

### Generating Secret Values

When a service needs a random secret key (e.g., session secret, API key), provide the user with shell commands to generate it:

```bash
# Generate a random hex secret (64 chars)
openssl rand -hex 32

# Generate a random base64 secret
openssl rand -base64 32
```

The generated value goes into the agenix-encrypted file in the format the service expects. For example, services using `environmentFile` expect `KEY=value` format:

```bash
cd secrets && agenix -e service-name.age
# Content: SERVICE_SECRET_KEY=<paste-generated-value>
```

## Development Notes

- All configurations support both stable and unstable nixpkgs channels, this is setup in flake.nix
- Home Manager is integrated for user-level configurations
- ZFS storage configurations available in `modules/zfs/` - this applies only to linux hosts, not darwin
- PostgreSQL integration testing framework in `tests/`
- Uses `alejandra` for nix code formatting
- Justfile provides cross-platform commands that detect current hostname automatically
- Git hooks in `.githooks/` are automatically installed when running `just` commands
  - Pre-commit hook runs `just fmt` to ensure all code is formatted before commit
  - No need to run 'just fmt', unless you want to syntax check the code
- Don't forget to 'git add' new files before building with nix. This will save you an error step
- **ZFS dataset safety**: When adding or modifying a `zfsDataset` option in a service module, always run `just dry-activate <hostname>` (requires root) before deploying. Review the output for any destructive ZFS actions (dataset destroy/rollback). The disko-zfs module auto-detects pools and will **destroy undeclared datasets**, so verify no existing datasets are accidentally dropped.
- **Auto-upgrade health checks**: When adding or modifying `healthChecks.extraScript` in a host's auto-upgrade config, ensure any commands used are available in PATH. The module provides a base set of common utilities (coreutils, gawk, gnugrep, gnused, findutils), but host-specific tools (e.g., `incus`) must be added via `healthChecks.extraScriptPackages`. Missing packages cause health checks to fail silently with "command not found", which triggers an automatic reboot to roll back. See `modules/auto-upgrade/default.nix` for the base path.



**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
5. **Clean up** - Clear stashes, prune remote branches
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
 - DO no commit or push unless asked
